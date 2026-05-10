import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/hf_models.dart';
import '../core/utils/storage_utils.dart';
import '../models/download_state.dart';

/// Downloads model zip file(s) from HuggingFace and extracts them locally.
///
/// Strategy:
///   1. Fetch file list from HF API — filter to .zip files only
///   2. Download each zip sequentially with resume support (Range header)
///   3. Extract each zip into the model directory using archive_io (streaming)
///   4. Delete zip after successful extraction to save space
///   5. UI updates throttled to 2/sec with EMA-smoothed speed
class DownloadManager {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 60),
  ));

  final _progressControllers = <String, StreamController<DownloadProgress>>{};

  // State
  bool _cancelled = false;
  int _totalZips = 0;
  int _completedZips = 0;

  // Byte tracking
  int _totalDownloaded = 0;
  int _totalModelBytes = 0;

  // EMA speed
  double _smoothedSpeedBps = 0;
  DateTime? _lastSample;
  int _lastSampleBytes = 0;

  // Throttle
  DateTime? _lastEmit;
  static const _emitInterval = Duration(milliseconds: 500);

  // ── Public API ─────────────────────────────────────────────────────────────

  Stream<DownloadProgress> progressStream(String modelId) {
    _progressControllers[modelId] ??=
        StreamController<DownloadProgress>.broadcast();
    return _progressControllers[modelId]!.stream;
  }

  void cancel() => _cancelled = true;

  /// Main entry point. Returns true on full success.
  Future<bool> startDownload(HFModelDef model) async {
    final modelId = model.id;
    _cancelled = false;
    _completedZips = 0;
    _totalDownloaded = 0;
    _totalModelBytes = model.sizeBytes;
    _smoothedSpeedBps = 0;
    _lastSample = null;
    _lastSampleBytes = 0;
    _lastEmit = null;

    _emit(modelId, const DownloadProgress(status: DownloadStatus.queued),
        force: true);

    try {
      // 1. Fetch zip file list + real total size from HF API
      final manifest = await _fetchZipManifest(model.repoId);
      final zipFiles = manifest.files;
      if (manifest.totalBytes > 0) {
        _totalModelBytes = manifest.totalBytes;
      }

      if (zipFiles.isEmpty) {
        _emit(
          modelId,
          const DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage:
                'No zip files found in the repository. Please check the model source.',
          ),
          force: true,
        );
        return false;
      }

      _totalZips = zipFiles.length;
      await _saveManifest(modelId, zipFiles);

      final destDir = await StorageUtils.getModelDirectory(modelId);
      final tmpDir = await StorageUtils.getDownloadTempDirectory(modelId);

      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.downloading,
          totalFiles: _totalZips,
          totalBytes: model.sizeBytes,
        ),
        force: true,
      );

      // 2. Download + extract each zip sequentially
      for (final zipName in zipFiles) {
        if (_cancelled) break;
        final ok = await _downloadAndExtract(
            model, zipName, tmpDir.path, destDir.path);
        if (!ok) {
          _emit(
            modelId,
            DownloadProgress(
              status: DownloadStatus.failed,
              errorMessage: 'Failed to download or extract $zipName',
            ),
            force: true,
          );
          return false;
        }
        _completedZips++;
      }

      if (_cancelled) {
        _emit(
          modelId,
          const DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage: 'Download cancelled',
          ),
          force: true,
        );
        return false;
      }

      // 3. Clean up temp dir
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}

      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.completed,
          filesCompleted: _completedZips,
          totalFiles: _totalZips,
          bytesReceived: _totalModelBytes,
          totalBytes: _totalModelBytes,
          overallProgress: 1.0,
        ),
        force: true,
      );
      return true;
    } catch (e) {
      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        ),
        force: true,
      );
      return false;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Manifest result carrying both file names and the real total size.
  static const _noManifest = _ZipManifest(files: [], totalBytes: 0);

  /// Fetch list of .zip files + their total byte size from HuggingFace API.
  Future<_ZipManifest> _fetchZipManifest(String repoId) async {
    // Always hit the API fresh — never use cached manifest after a new download
    try {
      final res = await _dio.get(
        'https://huggingface.co/api/models/$repoId',
        options: Options(headers: await _hfHeaders()),
      );
      final data = res.data as Map<String, dynamic>;
      final siblings = data['siblings'] as List? ?? [];

      final zips = <String>[];
      int totalBytes = 0;

      for (final s in siblings) {
        final name = s['rfilename'] as String? ?? '';
        if (name.toLowerCase().endsWith('.zip')) {
          zips.add(name);
          // HF API exposes file size in 'size' field (bytes)
          final size = s['size'];
          if (size is int) totalBytes += size;
        }
      }
      zips.sort(); // part001 < part002 < …

      // Fallback: use repo-level usedStorage if per-file sizes are missing
      if (totalBytes == 0) {
        final usedStorage = data['usedStorage'];
        if (usedStorage is int) totalBytes = usedStorage;
      }

      if (zips.isEmpty) return _noManifest;
      await _saveManifest(repoId, zips);
      return _ZipManifest(files: zips, totalBytes: totalBytes);
    } catch (_) {
      // Fallback: try cached manifest (no size info)
      final cached = await _loadManifest(repoId);
      return _ZipManifest(files: cached, totalBytes: 0);
    }
  }

  Future<List<String>> _loadManifest(String repoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('manifest_$repoId');
      if (raw == null) return [];
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveManifest(String modelId, List<String> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manifest_$modelId', jsonEncode(files));
  }

  Future<Map<String, String>> _hfHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('hf_token')?.trim();
    if (token == null || token.isEmpty) return const {};

    return {'Authorization': 'Bearer $token'};
  }

  Future<int> _remoteContentLength(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          headers: {
            ...await _hfHeaders(),
            'User-Agent': 'FixGemma/1.0',
          },
        ),
      );

      final contentLength = response.headers.value(Headers.contentLengthHeader);
      return int.tryParse(contentLength ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int _zipProgressShare() => _totalModelBytes ~/ _totalZips.clamp(1, 9999);

  /// Download a single zip file then extract it in-place.
  Future<bool> _downloadAndExtract(
    HFModelDef model,
    String zipName,
    String tmpPath,
    String destPath,
  ) async {
    final modelId = model.id;
    final url = 'https://huggingface.co/${model.repoId}/resolve/main/$zipName';
    final zipPath = '$tmpPath/$zipName';

    // ── Step A: Download ────────────────────────────────────────────────────
    final zipFile = File(zipPath);
    int existingBytes = 0;
    if (await zipFile.exists()) {
      existingBytes = await zipFile.length();
    } else {
      await zipFile.parent.create(recursive: true);
    }

    final expectedZipBytes = await _remoteContentLength(url);
    final hasCompleteZip =
        expectedZipBytes > 0 && existingBytes == expectedZipBytes;

    // Dio does not append Range responses to an existing file here. A partial
    // temp zip must be replaced, otherwise extraction sees a corrupt archive.
    if (existingBytes > 0 && !hasCompleteZip) {
      try {
        await zipFile.delete();
      } catch (_) {}
      existingBytes = 0;
    }

    try {
      if (!hasCompleteZip) {
        await _dio.download(
          url,
          zipPath,
          onReceiveProgress: (received, total) {
            if (_cancelled) return;

            final actual = existingBytes + received;
            // We track progress based on the total model size across all zips.
            // Approximate: assume equal zip sizes.
            final zipShare = _zipProgressShare();
            _totalDownloaded =
                (_completedZips * zipShare) + actual.clamp(0, zipShare);

            // EMA speed (sample every 500ms)
            final now = DateTime.now();
            if (_lastSample != null) {
              final elapsed =
                  now.difference(_lastSample!).inMilliseconds / 1000.0;
              if (elapsed >= 0.5) {
                final delta = _totalDownloaded - _lastSampleBytes;
                final instant = delta / elapsed;
                _smoothedSpeedBps = _smoothedSpeedBps == 0
                    ? instant
                    : 0.2 * instant + 0.8 * _smoothedSpeedBps;
                _lastSample = now;
                _lastSampleBytes = _totalDownloaded;
              }
            } else {
              _lastSample = now;
              _lastSampleBytes = _totalDownloaded;
            }

            final progress =
                (_totalDownloaded / _totalModelBytes).clamp(0.0, 1.0);
            final remaining = (_totalModelBytes - _totalDownloaded)
                .clamp(0, _totalModelBytes);
            final eta = _smoothedSpeedBps > 0
                ? Duration(seconds: (remaining / _smoothedSpeedBps).round())
                : null;

            _emit(
              modelId,
              DownloadProgress(
                status: DownloadStatus.downloading,
                filesCompleted: _completedZips,
                totalFiles: _totalZips,
                bytesReceived: _totalDownloaded,
                totalBytes: _totalModelBytes,
                overallProgress: progress,
                speedBps: _smoothedSpeedBps,
                eta: eta,
              ),
            );
          },
          deleteOnError: false,
          options: Options(
            receiveTimeout: const Duration(minutes: 60),
            headers: {
              ...await _hfHeaders(),
              'User-Agent': 'FixGemma/1.0',
            },
          ),
        );
      } else {
        _totalDownloaded = (_completedZips + 1) * _zipProgressShare();
      }
    } on DioException {
      rethrow;
    }

    if (expectedZipBytes > 0) {
      final downloadedBytes = await zipFile.length();
      if (downloadedBytes != expectedZipBytes) {
        _emit(
          modelId,
          DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage:
                'Download incomplete: got $downloadedBytes of $expectedZipBytes bytes',
          ),
          force: true,
        );
        return false;
      }
    }

    if (_cancelled) return false;

    // ── Step B: Extract ─────────────────────────────────────────────────────
    _emit(
      modelId,
      DownloadProgress(
        status: DownloadStatus.extracting,
        filesCompleted: _completedZips,
        totalFiles: _totalZips,
        bytesReceived: _totalDownloaded,
        totalBytes: _totalModelBytes,
        overallProgress: ((_completedZips + 0.5) / _totalZips).clamp(0.0, 1.0),
        extractProgress: 0.0,
      ),
      force: true,
    );

    final ok = await _extractZip(
      modelId: modelId,
      zipPath: zipPath,
      destPath: destPath,
    );
    if (!ok) return false;

    // Delete zip after successful extraction to free space
    try {
      await zipFile.delete();
    } catch (_) {}

    return true;
  }

  /// Extract a zip file in a background Isolate so the main thread stays
  /// responsive. Progress (0.0–1.0) is sent back through a ReceivePort.
  Future<bool> _extractZip({
    required String modelId,
    required String zipPath,
    required String destPath,
  }) async {
    final receivePort = ReceivePort();
    Isolate? worker;

    try {
      worker = await Isolate.spawn(
        _extractZipIsolate,
        _ExtractArgs(
          sendPort: receivePort.sendPort,
          zipPath: zipPath,
          destPath: destPath,
        ),
      );

      await for (final msg in receivePort) {
        if (_cancelled) {
          worker.kill(priority: Isolate.immediate);
          receivePort.close();
          return false;
        }

        if (msg is double) {
          // Progress update 0.0–1.0
          final overallPct =
              ((_completedZips + msg) / _totalZips).clamp(0.0, 1.0);
          _emit(
            modelId,
            DownloadProgress(
              status: DownloadStatus.extracting,
              filesCompleted: _completedZips,
              totalFiles: _totalZips,
              bytesReceived: _totalDownloaded,
              totalBytes: _totalModelBytes,
              overallProgress: overallPct,
              extractProgress: msg,
            ),
            force: true,
          );
        } else if (msg is String) {
          // Error message from isolate
          receivePort.close();
          _emit(
            modelId,
            DownloadProgress(
              status: DownloadStatus.failed,
              errorMessage: 'Extraction failed: $msg',
            ),
            force: true,
          );
          return false;
        } else if (msg == null) {
          // null = success signal
          receivePort.close();
          return true;
        }
      }

      return false; // receivePort closed unexpectedly
    } catch (e) {
      receivePort.close();
      worker?.kill();
      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.failed,
          errorMessage: 'Extraction error: $e',
        ),
        force: true,
      );
      return false;
    }
  }

  /// Top-level function run inside the background Isolate.
  /// Sends: double (progress 0-1), String (error), or null (done).
  static void _extractZipIsolate(_ExtractArgs args) {
    try {
      final inputStream = InputFileStream(args.zipPath);
      final archive = ZipDecoder().decodeStream(inputStream);
      final files = archive.files.where((f) => !f.isDirectory).toList();
      final total = files.length;
      if (total == 0) {
        inputStream.closeSync();
        args.sendPort.send('Zip contained no extractable model files');
        return;
      }
      int done = 0;

      for (final entry in files) {
        final outPath = _safeExtractPath(args.destPath, entry.name);
        if (outPath == null) {
          done++;
          args.sendPort.send(total > 0 ? done / total : 0.0);
          continue;
        }
        final outFile = File(outPath);
        outFile.parent.createSync(recursive: true);
        final outputStream = OutputFileStream(outPath);
        entry.writeContent(outputStream);
        outputStream.closeSync();
        done++;
        // Send progress fraction
        args.sendPort.send(total > 0 ? done / total : 0.0);
      }

      inputStream.closeSync();
      // null = success
      args.sendPort.send(null);
    } catch (e) {
      args.sendPort.send(e.toString());
    }
  }

  static String? _safeExtractPath(String destPath, String entryName) {
    var name = entryName.replaceAll('\\', '/');

    final driveIndex = name.indexOf(':/');
    if (driveIndex >= 0) {
      name = name.substring(driveIndex + 2);
    }

    while (name.startsWith('/')) {
      name = name.substring(1);
    }

    final parts = name
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList(growable: false);

    if (parts.isEmpty || parts.any((part) => part == '..')) return null;

    return '$destPath/${parts.join('/')}';
  }

  void _emit(String modelId, DownloadProgress p, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastEmit != null &&
        now.difference(_lastEmit!) < _emitInterval) {
      return;
    }
    _lastEmit = now;
    _progressControllers[modelId]?.add(p);
  }

  void dispose() {
    for (final c in _progressControllers.values) {
      c.close();
    }
    _progressControllers.clear();
  }
}

// ── Value type returned by _fetchZipManifest ───────────────────────────────
class _ZipManifest {
  final List<String> files;
  final int totalBytes; // 0 when unknown

  const _ZipManifest({required this.files, required this.totalBytes});
}

// ── Args passed to the background extraction Isolate ──────────────────────
class _ExtractArgs {
  final SendPort sendPort;
  final String zipPath;
  final String destPath;

  const _ExtractArgs({
    required this.sendPort,
    required this.zipPath,
    required this.destPath,
  });
}

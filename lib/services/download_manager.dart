import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/hf_models.dart';
import '../core/utils/storage_utils.dart';
import '../models/download_state.dart';

/// Downloads model zip file(s) from HuggingFace via the OS background download
/// service (Android DownloadWorker / iOS URLSession) and then extracts them.
///
/// Strategy:
///   1. Fetch file list from HF API — filter to .zip files only.
///   2. Enqueue each zip through [FileDownloader] with allowPause + retries so
///      the download continues even when the app is backgrounded or killed.
///   3. Show a foreground notification so the OS keeps the service alive.
///   4. After each zip lands in the temp directory, extract it via Isolate.
///   5. Delete the zip after successful extraction to save space.
class DownloadManager {
  // ── FileDownloader task group ───────────────────────────────────────────
  static const _group = 'model_zips';

  // Used only for the HF manifest fetch (lightweight HEAD / GET calls).
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  // Progress streams keyed by modelId.
  final _progressControllers = <String, StreamController<DownloadProgress>>{};

  // ── Per-download state ──────────────────────────────────────────────────
  bool _cancelled = false;
  int _totalZips = 0;
  int _completedZips = 0;
  int _totalDownloaded = 0;
  int _totalModelBytes = 0;
  double _smoothedSpeedBps = 0;
  DateTime? _lastSample;
  int _lastSampleBytes = 0;
  DateTime? _lastEmit;
  static const _emitInterval = Duration(milliseconds: 500);

  // ── Public API ──────────────────────────────────────────────────────────

  Stream<DownloadProgress> progressStream(String modelId) {
    _progressControllers[modelId] ??=
        StreamController<DownloadProgress>.broadcast();
    return _progressControllers[modelId]!.stream;
  }

  void cancel() => _cancelled = true;

  /// Initialise the [FileDownloader] singleton.
  /// Call once from [main] (or lazily before first download).
  static Future<void> initialise() async {
    await FileDownloader().start();

    // Configure foreground notification (Android) so the OS keeps the process
    // alive while downloading large model files.
    FileDownloader().configureNotificationForGroup(
      _group,
      running: const TaskNotification(
        'FixGemma — downloading model',
        'Downloading {filename} ({progress}%)',
      ),
      complete: const TaskNotification(
        'FixGemma — download complete',
        '{filename} is ready',
      ),
      error: const TaskNotification(
        'FixGemma — download failed',
        '{filename} could not be downloaded',
      ),
      paused: const TaskNotification(
        'FixGemma — download paused',
        '{filename} is paused',
      ),
      progressBar: true,
    );
  }

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
          totalBytes: _totalModelBytes,
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

  // ── Private helpers ─────────────────────────────────────────────────────

  static const _noManifest = _ZipManifest(files: [], totalBytes: 0);

  Future<_ZipManifest> _fetchZipManifest(String repoId) async {
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
          final size = s['size'];
          if (size is int) totalBytes += size;
        }
      }
      zips.sort();

      if (totalBytes == 0) {
        final usedStorage = data['usedStorage'];
        if (usedStorage is int) totalBytes = usedStorage;
      }

      if (zips.isEmpty) return _noManifest;
      await _saveManifest(repoId, zips);
      return _ZipManifest(files: zips, totalBytes: totalBytes);
    } catch (_) {
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

  int _zipProgressShare() => _totalModelBytes ~/ _totalZips.clamp(1, 9999);

  /// Download a single zip using [FileDownloader] (background-safe), then
  /// extract it in-place via an Isolate.
  Future<bool> _downloadAndExtract(
    HFModelDef model,
    String zipName,
    String tmpPath,
    String destPath,
  ) async {
    final modelId = model.id;
    final url =
        'https://huggingface.co/${model.repoId}/resolve/main/$zipName';
    final zipFilePath = '$tmpPath/$zipName';

    // Ensure tmp dir exists
    await Directory(tmpPath).create(recursive: true);

    // ── Step A: Background download ─────────────────────────────────────
    // Check if the zip is already fully downloaded from a previous attempt.
    final zipFile = File(zipFilePath);
    bool alreadyComplete = false;
    if (await zipFile.exists()) {
      // Trust a complete file only if its size matches the remote header.
      final expectedBytes = await _remoteContentLength(url);
      if (expectedBytes > 0 && await zipFile.length() == expectedBytes) {
        alreadyComplete = true;
        _totalDownloaded = (_completedZips + 1) * _zipProgressShare();
      } else {
        // Partial/corrupt — delete and re-download.
        try { await zipFile.delete(); } catch (_) {}
      }
    }

    if (!alreadyComplete) {
      final headers = await _hfHeaders();

      // background_downloader requires a stable base directory. We target
      // BaseDirectory.temporary (= cacheDir on Android / tmp on iOS) and
      // use a subdirectory for the model's temp files.
      //
      // We then move the file to our custom tmpPath after completion.
      final appTmp = await getTemporaryDirectory();
      final bgSubdir = 'fixgemma_dl/$modelId';
      final taskId = '${modelId}_$zipName'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // Remove any stale task record with the same ID.
      await FileDownloader().cancelTasksWithIds([taskId]);

      final task = DownloadTask(
        taskId: taskId,
        url: url,
        filename: zipName,
        headers: headers,
        directory: bgSubdir,
        baseDirectory: BaseDirectory.temporary,
        group: _group,
        updates: Updates.statusAndProgress,
        allowPause: true,   // Auto-pause/resume when the 9-min Android limit is hit
        retries: 3,         // Retry up to 3× on failure
        metaData: jsonEncode({'modelId': modelId, 'zipName': zipName}),
        displayName: 'Downloading $zipName',
      );

      final completer = Completer<bool>();

      final result = await FileDownloader().download(
        task,
        onProgress: (progress) {
          if (_cancelled) return;

          final zipShare = _zipProgressShare();
          _totalDownloaded = (_completedZips * zipShare) +
              (progress * zipShare).round().clamp(0, zipShare);

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

          final overallProgress =
              (_totalDownloaded / _totalModelBytes).clamp(0.0, 1.0);
          final remaining =
              (_totalModelBytes - _totalDownloaded).clamp(0, _totalModelBytes);
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
              overallProgress: overallProgress,
              speedBps: _smoothedSpeedBps,
              eta: eta,
            ),
          );
        },
        onStatus: (status) {
          if (status == TaskStatus.canceled && !completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      if (_cancelled) return false;

      if (result.status != TaskStatus.complete) {
        _emit(
          modelId,
          DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage:
                'Download failed: ${result.status} — ${result.exception?.description ?? 'unknown error'}',
          ),
          force: true,
        );
        return false;
      }

      // Move the downloaded file from background_downloader's temp dir to our
      // custom tmpPath so the extraction step can find it.
      final bgFile = File(
          '${appTmp.path}/$bgSubdir/$zipName');
      if (await bgFile.exists()) {
        await bgFile.rename(zipFilePath);
      } else {
        // background_downloader may have already placed it at the task path.
        final taskPath = await task.filePath();
        if (taskPath != zipFilePath) {
          final src = File(taskPath);
          if (await src.exists()) await src.rename(zipFilePath);
        }
      }
    }

    if (_cancelled) return false;

    // ── Step B: Extract ─────────────────────────────────────────────────
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
      zipPath: zipFilePath,
      destPath: destPath,
    );
    if (!ok) return false;

    // Delete zip after extraction to free space.
    try { await File(zipFilePath).delete(); } catch (_) {}

    return true;
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
      final cl = response.headers.value(Headers.contentLengthHeader);
      return int.tryParse(cl ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
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
          receivePort.close();
          return true;
        }
      }

      return false;
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
        args.sendPort.send(total > 0 ? done / total : 0.0);
      }

      inputStream.closeSync();
      args.sendPort.send(null); // null = success
    } catch (e) {
      args.sendPort.send(e.toString());
    }
  }

  static String? _safeExtractPath(String destPath, String entryName) {
    var name = entryName.replaceAll('\\', '/');

    final driveIndex = name.indexOf(':/');
    if (driveIndex >= 0) name = name.substring(driveIndex + 2);

    while (name.startsWith('/')) name = name.substring(1);

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
    for (final c in _progressControllers.values) c.close();
    _progressControllers.clear();
  }
}

// ── Value type returned by _fetchZipManifest ───────────────────────────────
class _ZipManifest {
  final List<String> files;
  final int totalBytes;
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

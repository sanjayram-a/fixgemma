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
import '../core/utils/cactus_model_locator.dart';
import '../core/utils/storage_utils.dart';
import '../models/download_state.dart';

/// Persistent ledger entry stored in SharedPreferences so downloads survive
/// app kill + restart. Tracks which zips have been fully extracted already.
class _LedgerEntry {
  final String modelId;
  final String repoId;
  final List<String> allZips;
  final List<String> extractedZips;
  final int totalBytes;
  String status; // "active", "done", "failed"

  _LedgerEntry({
    required this.modelId,
    required this.repoId,
    required this.allZips,
    required this.extractedZips,
    required this.totalBytes,
    this.status = 'active',
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'repoId': repoId,
        'allZips': allZips,
        'extractedZips': extractedZips,
        'totalBytes': totalBytes,
        'status': status,
      };

  factory _LedgerEntry.fromJson(Map<String, dynamic> j) => _LedgerEntry(
        modelId: j['modelId'] as String,
        repoId: j['repoId'] as String,
        allZips: List<String>.from(j['allZips'] as List),
        extractedZips: List<String>.from(j['extractedZips'] as List),
        totalBytes: j['totalBytes'] as int? ?? 0,
        status: j['status'] as String? ?? 'active',
      );
}

/// Downloads model zip file(s) from HuggingFace via the OS background download
/// service and then extracts them.
///
/// Resilience features:
///   - Persists a ledger so partially-completed multi-zip downloads survive
///     app kill and resume only the remaining zips on next launch.
///   - Each zip gets up to 3 download attempts.
///   - On final failure the entire partial model is deleted so the user
///     starts fresh on next try.
///   - Foreground notification keeps the Android process alive.
class DownloadManager {
  static const _group = 'model_zips';
  static const _maxRetries = 3;
  static const _ledgerKey = 'dl_ledger';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  final _progressControllers = <String, StreamController<DownloadProgress>>{};

  // ── Per-download in-memory state ────────────────────────────────────────
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

  /// Initialise the [FileDownloader] singleton + register callbacks so
  /// tasks that finish while the app is dead are picked up on relaunch.
  static Future<void> initialise() async {
    await FileDownloader().start();

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

    // Track tasks so we can query completed/failed tasks after app restart.
    FileDownloader().trackTasks();
  }

  /// Called on app resume / startup. Returns the modelId that was being
  /// downloaded (if any) so the provider can re-subscribe to progress.
  Future<String?> recoverAfterAppRestart() async {
    final ledger = await _loadLedger();
    if (ledger == null || ledger.status != 'active') return null;
    return ledger.modelId;
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
      if (manifest.totalBytes > 0) _totalModelBytes = manifest.totalBytes;

      if (zipFiles.isEmpty) {
        _emit(
          modelId,
          const DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage: 'No zip files found in the repository.',
          ),
          force: true,
        );
        return false;
      }

      _totalZips = zipFiles.length;
      await _saveManifest(modelId, zipFiles);

      final destDir = await StorageUtils.getModelDirectory(modelId);
      final tmpDir = await StorageUtils.getDownloadTempDirectory(modelId);
      final stagingDir = Directory('${destDir.path}__staging');

      // Check ledger for a previous partial run so we can resume.
      final existingLedger = await _loadLedger();
      List<String> alreadyExtracted = [];

      if (existingLedger != null &&
          existingLedger.modelId == modelId &&
          existingLedger.status == 'active') {
        // Resume — keep staging dir and skip extracted zips.
        alreadyExtracted = existingLedger.extractedZips;
        _completedZips = alreadyExtracted.length;
      } else {
        // Fresh start — wipe everything.
        for (final dir in [destDir, tmpDir, stagingDir]) {
          if (await dir.exists()) {
            try { await dir.delete(recursive: true); } catch (_) {}
          }
        }
        await _purgeBgCache(modelId);
      }

      await tmpDir.create(recursive: true);
      await stagingDir.create(recursive: true);

      // Persist ledger so we can resume after app kill.
      final ledger = _LedgerEntry(
        modelId: modelId,
        repoId: model.repoId,
        allZips: zipFiles,
        extractedZips: List<String>.from(alreadyExtracted),
        totalBytes: _totalModelBytes,
      );
      await _saveLedger(ledger);

      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.downloading,
          totalFiles: _totalZips,
          totalBytes: _totalModelBytes,
          filesCompleted: _completedZips,
        ),
        force: true,
      );

      // 2. Download + extract each zip (skip already-extracted ones)
      for (final zipName in zipFiles) {
        if (_cancelled) break;
        if (alreadyExtracted.contains(zipName)) continue;

        final ok = await _downloadAndExtractWithRetries(
          model, zipName, tmpDir.path, stagingDir.path, ledger,
        );
        if (!ok) {
          // Total failure on this zip — nuke everything.
          await _nukeAllPartials(modelId, destDir, tmpDir, stagingDir);
          await _clearLedger();
          _emit(
            modelId,
            DownloadProgress(
              status: DownloadStatus.failed,
              errorMessage:
                  'Failed to download $zipName after $_maxRetries attempts. '
                  'All partial data deleted — tap Retry to start fresh.',
            ),
            force: true,
          );
          return false;
        }
        _completedZips++;
        ledger.extractedZips.add(zipName);
        await _saveLedger(ledger);
      }

      if (_cancelled) {
        // Don't wipe on cancel — user may resume later.
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

      // 3. Validate the extracted result is a loadable model.
      final hasModel = await CactusModelLocator.hasModel(stagingDir.path);
      if (!hasModel) {
        await _nukeAllPartials(modelId, destDir, tmpDir, stagingDir);
        await _clearLedger();
        _emit(
          modelId,
          const DownloadProgress(
            status: DownloadStatus.failed,
            errorMessage: 'Extraction finished but no model files found. '
                'All partial data deleted — tap Retry to start fresh.',
          ),
          force: true,
        );
        return false;
      }

      // 4. Atomically promote to live directory.
      try {
        if (await destDir.exists()) await destDir.delete(recursive: true);
      } catch (_) {}
      await stagingDir.rename(destDir.path);

      // 5. Clean up
      try { await tmpDir.delete(recursive: true); } catch (_) {}
      await _purgeBgCache(modelId);

      // Mark ledger done
      ledger.status = 'done';
      await _saveLedger(ledger);

      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.completed,
          filesCompleted: _totalZips,
          totalFiles: _totalZips,
          bytesReceived: _totalModelBytes,
          totalBytes: _totalModelBytes,
          overallProgress: 1.0,
        ),
        force: true,
      );
      return true;
    } catch (e) {
      // Unexpected error — nuke partials so next retry is clean.
      try {
        final destDir = await StorageUtils.getModelDirectory(modelId);
        final tmpDir = await StorageUtils.getDownloadTempDirectory(modelId);
        final stagingDir = Directory('${destDir.path}__staging');
        await _nukeAllPartials(modelId, destDir, tmpDir, stagingDir);
      } catch (_) {}
      await _clearLedger();
      _emit(
        modelId,
        DownloadProgress(
          status: DownloadStatus.failed,
          errorMessage: 'Unexpected error: $e\n'
              'All partial data deleted — tap Retry to start fresh.',
        ),
        force: true,
      );
      return false;
    }
  }

  // ── Retry wrapper ──────────────────────────────────────────────────────

  /// Tries to download + extract [zipName] up to [_maxRetries] times.
  /// On each failure the partial zip is deleted so the next attempt starts
  /// from scratch for that zip. Returns false only if all attempts fail.
  Future<bool> _downloadAndExtractWithRetries(
    HFModelDef model,
    String zipName,
    String tmpPath,
    String destPath,
    _LedgerEntry ledger,
  ) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      if (_cancelled) return false;

      if (attempt > 1) {
        _emit(
          model.id,
          DownloadProgress(
            status: DownloadStatus.downloading,
            filesCompleted: _completedZips,
            totalFiles: _totalZips,
            bytesReceived: _totalDownloaded,
            totalBytes: _totalModelBytes,
            retryAttempt: attempt,
            maxRetries: _maxRetries,
            overallProgress:
                (_totalDownloaded / _totalModelBytes).clamp(0.0, 1.0),
          ),
          force: true,
        );
        // Brief pause before retry to avoid hammering the server.
        await Future.delayed(Duration(seconds: attempt * 2));
      }

      final ok = await _downloadAndExtract(
        model, zipName, tmpPath, destPath, attempt: attempt,
      );
      if (ok) return true;

      // Clean up partial zip for this attempt so next attempt is fresh.
      try {
        final partial = File('$tmpPath/$zipName');
        if (await partial.exists()) await partial.delete();
      } catch (_) {}
    }
    return false; // all retries exhausted
  }

  // ── Core download + extract (single attempt) ───────────────────────────

  Future<bool> _downloadAndExtract(
    HFModelDef model,
    String zipName,
    String tmpPath,
    String destPath, {
    int attempt = 1,
  }) async {
    final modelId = model.id;
    final url =
        'https://huggingface.co/${model.repoId}/resolve/main/$zipName';
    final zipFilePath = '$tmpPath/$zipName';

    await Directory(tmpPath).create(recursive: true);

    // ── Step A: Background download ─────────────────────────────────────
    final zipFile = File(zipFilePath);
    bool alreadyComplete = false;
    if (await zipFile.exists()) {
      final expectedBytes = await _remoteContentLength(url);
      if (expectedBytes > 0 && await zipFile.length() == expectedBytes) {
        alreadyComplete = true;
        _totalDownloaded = (_completedZips + 1) * _zipProgressShare();
      } else {
        try { await zipFile.delete(); } catch (_) {}
      }
    }

    if (!alreadyComplete) {
      final headers = await _hfHeaders();
      final appTmp = await getTemporaryDirectory();
      final bgSubdir = 'fixgemma_dl/$modelId';
      final taskBaseId =
          '${modelId}_$zipName'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final taskId =
          '${taskBaseId}_a${attempt}_${DateTime.now().millisecondsSinceEpoch}';

      final task = DownloadTask(
        taskId: taskId,
        url: url,
        filename: zipName,
        headers: headers,
        directory: bgSubdir,
        baseDirectory: BaseDirectory.temporary,
        group: _group,
        updates: Updates.statusAndProgress,
        allowPause: true,
        retries: 0,
        metaData: jsonEncode({'modelId': modelId, 'zipName': zipName}),
        displayName: 'Downloading $zipName',
      );

      final result = await FileDownloader().download(
        task,
        onProgress: (progress) {
          if (_cancelled) return;
          final zipShare = _zipProgressShare();
          _totalDownloaded = (_completedZips * zipShare) +
              (progress * zipShare).round().clamp(0, zipShare);
          _updateSpeed();
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
              retryAttempt: attempt > 1 ? attempt : 0,
              maxRetries: _maxRetries,
            ),
          );
        },
        onStatus: (_) {},
      );

      if (_cancelled) return false;

      if (result.status != TaskStatus.complete) return false;

      // Move downloaded file to our tmp path.
      final bgFile = File('${appTmp.path}/$bgSubdir/$zipName');
      if (await bgFile.exists()) {
        await bgFile.rename(zipFilePath);
      } else {
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
        overallProgress:
            ((_completedZips + 0.5) / _totalZips).clamp(0.0, 1.0),
        extractProgress: 0.0,
        retryAttempt: attempt > 1 ? attempt : 0,
        maxRetries: _maxRetries,
      ),
      force: true,
    );

    final ok = await _extractZip(
      modelId: modelId,
      zipPath: zipFilePath,
      destPath: destPath,
    );
    if (!ok) return false;

    // Delete zip after successful extraction to free space.
    try { await File(zipFilePath).delete(); } catch (_) {}
    return true;
  }

  // ── Speed tracking ─────────────────────────────────────────────────────

  void _updateSpeed() {
    final now = DateTime.now();
    if (_lastSample != null) {
      final elapsed = now.difference(_lastSample!).inMilliseconds / 1000.0;
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
  }

  // ── Ledger persistence ─────────────────────────────────────────────────

  Future<void> _saveLedger(_LedgerEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ledgerKey, jsonEncode(entry.toJson()));
  }

  Future<_LedgerEntry?> _loadLedger() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ledgerKey);
    if (raw == null) return null;
    try {
      return _LedgerEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearLedger() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ledgerKey);
  }

  // ── Cleanup helpers ────────────────────────────────────────────────────

  Future<void> _nukeAllPartials(
    String modelId,
    Directory destDir,
    Directory tmpDir,
    Directory stagingDir,
  ) async {
    for (final dir in [destDir, tmpDir, stagingDir]) {
      if (await dir.exists()) {
        try { await dir.delete(recursive: true); } catch (_) {}
      }
    }
    await _purgeBgCache(modelId);
  }

  Future<void> _purgeBgCache(String modelId) async {
    try {
      final appTmp = await getTemporaryDirectory();
      final bgCache = Directory('${appTmp.path}/fixgemma_dl/$modelId');
      if (await bgCache.exists()) await bgCache.delete(recursive: true);
    } catch (_) {}
  }

  // ── HF helpers ─────────────────────────────────────────────────────────

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

  // ── Extraction via Isolate ─────────────────────────────────────────────

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

  // ── Emit helpers ───────────────────────────────────────────────────────

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

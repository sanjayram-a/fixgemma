import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/hf_models.dart';
import '../core/utils/cactus_model_locator.dart';
import '../core/utils/storage_utils.dart';
import '../models/ai_model.dart';
import '../models/download_state.dart';
import '../services/download_manager.dart';
import '../services/cactus_service.dart';

// ── Download manager singleton ─────────────────────────────────────────────
final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final mgr = DownloadManager();
  ref.onDispose(mgr.dispose);
  return mgr;
});

// ── Cactus service singleton ───────────────────────────────────────────────
final cactusServiceProvider = Provider<CactusService>((ref) {
  final svc = CactusService();
  ref.onDispose(svc.dispose);
  return svc;
});

// ── Model status state ─────────────────────────────────────────────────────
class ModelState {
  final List<AIModel> models;
  final String? activeModelId;
  final Map<String, DownloadProgress> downloadProgress;

  const ModelState({
    required this.models,
    this.activeModelId,
    this.downloadProgress = const {},
  });

  AIModel? get activeModel => models.cast<AIModel?>().firstWhere(
        (m) => m?.id == activeModelId,
        orElse: () => null,
      );

  ModelState copyWith({
    List<AIModel>? models,
    String? activeModelId,
    Map<String, DownloadProgress>? downloadProgress,
  }) =>
      ModelState(
        models: models ?? this.models,
        activeModelId: activeModelId ?? this.activeModelId,
        downloadProgress: downloadProgress ?? this.downloadProgress,
      );
}

class ModelNotifier extends StateNotifier<ModelState>
    with WidgetsBindingObserver {
  final DownloadManager _downloader;
  final CactusService _cactus;
  final Map<String, StreamSubscription<DownloadProgress>> _subs = {};

  ModelNotifier(this._downloader, this._cactus)
      : super(ModelState(models: _buildInitialModels())) {
    WidgetsBinding.instance.addObserver(this);
  }

  static List<AIModel> _buildInitialModels() {
    return kAvailableModels.map((def) => AIModel(id: def.id)).toList();
  }

  Future<void> init() async {
    // Check which models are already downloaded
    for (final model in state.models) {
      final dir = await StorageUtils.getModelDirectory(model.id);
      if (!await dir.exists()) continue;

      final hasModel = await CactusModelLocator.hasModel(dir.path);
      if (hasModel) {
        model.status = ModelStatus.downloaded;
        model.localDirPath = dir.path;
      }
    }

    // Restore last active model
    final prefs = await SharedPreferences.getInstance();
    final lastModel = prefs.getString('active_model_id');
    if (lastModel != null) {
      final models = List<AIModel>.from(state.models);
      state = state.copyWith(models: models, activeModelId: lastModel);
    } else {
      state = state.copyWith(models: List.from(state.models));
    }

    // Check for downloads that were active when the app was killed.
    await _recoverInFlightDownload();
  }

  /// Called by the lifecycle observer when the app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      _recoverInFlightDownload();
    }
  }

  /// Check if there's a download that was active before app kill/background
  /// and resume it automatically.
  Future<void> _recoverInFlightDownload() async {
    final modelId = await _downloader.recoverAfterAppRestart();
    if (modelId == null) return;

    // Don't resume if already downloading or already completed.
    final existing = state.models.firstWhere(
      (m) => m.id == modelId,
      orElse: () => AIModel(id: modelId),
    );
    if (existing.status == ModelStatus.downloading ||
        existing.status == ModelStatus.downloaded ||
        existing.status == ModelStatus.ready) {
      return;
    }

    final def = modelById(modelId);
    if (def == null) return;

    // Re-trigger the download — it will check the ledger and skip
    // already-extracted zips.
    startDownload(modelId);
  }

  Future<void> startDownload(String modelId) async {
    final def = modelById(modelId);
    if (def == null) return;
    final localDir = await StorageUtils.getModelDirectory(modelId);

    // Subscribe to progress stream
    _subs[modelId]?.cancel();
    _subs[modelId] = _downloader.progressStream(modelId).listen((progress) {
      final updated =
          Map<String, DownloadProgress>.from(state.downloadProgress);
      updated[modelId] = progress;

      // Update model status
      final models = state.models.map((m) {
        if (m.id != modelId) return m;

        final shouldAttachLocalDir =
            progress.status == DownloadStatus.completed ||
                m.status == ModelStatus.downloaded ||
                m.status == ModelStatus.ready ||
                m.status == ModelStatus.loading;

        final updated2 = AIModel(
          id: m.id,
          status: _progressToModelStatus(progress.status),
          filesCompleted: progress.filesCompleted,
          totalFiles: progress.totalFiles,
          localDirPath:
              shouldAttachLocalDir ? (m.localDirPath ?? localDir.path) : null,
          errorMessage: progress.errorMessage,
        );
        return updated2;
      }).toList();

      state = state.copyWith(models: models, downloadProgress: updated);

      if (progress.isDone) {
        _onDownloadComplete(modelId);
      }
    });

    await _downloader.startDownload(def);
  }

  void _onDownloadComplete(String modelId) async {
    final dir = await StorageUtils.getModelDirectory(modelId);
    final models = state.models.map((m) {
      if (m.id != modelId) return m;
      return AIModel(
        id: m.id,
        status: ModelStatus.downloaded,
        localDirPath: dir.path,
        downloadedAt: DateTime.now(),
      );
    }).toList();
    state = state.copyWith(models: models);
  }

  Future<void> loadModel(String modelId) async {
    final model = state.models.firstWhere((m) => m.id == modelId);
    final dir = await StorageUtils.getModelDirectory(modelId);
    final modelDirPath = dir.path;

    if (model.localDirPath != modelDirPath) {
      _setModelLocalDir(modelId, modelDirPath);
    }

    // Update status to loading
    _updateModelStatus(modelId, ModelStatus.loading);

    await _cactus.loadModel(modelDirPath);

    if (_cactus.isReady) {
      _updateModelStatus(modelId, ModelStatus.ready);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_model_id', modelId);
      state = state.copyWith(activeModelId: modelId);
    } else {
      _updateModelStatus(modelId, ModelStatus.error,
          error: _cactus.errorMessage);
    }
  }

  Future<void> deleteModel(String modelId) async {
    await StorageUtils.deleteModel(modelId);
    _updateModelStatus(modelId, ModelStatus.notDownloaded);
    if (state.activeModelId == modelId) {
      _cactus.unloadModel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_model_id');
      state = state.copyWith(activeModelId: null);
    }
  }

  void _updateModelStatus(String modelId, ModelStatus status, {String? error}) {
    final models = state.models.map((m) {
      if (m.id != modelId) return m;
      return AIModel(
        id: m.id,
        status: status,
        localDirPath: m.localDirPath,
        errorMessage: error,
        filesCompleted: m.filesCompleted,
        totalFiles: m.totalFiles,
        downloadedAt: m.downloadedAt,
      );
    }).toList();
    state = state.copyWith(models: models);
  }

  void _setModelLocalDir(String modelId, String localDirPath) {
    final models = state.models.map((m) {
      if (m.id != modelId) return m;
      return AIModel(
        id: m.id,
        status: m.status,
        localDirPath: localDirPath,
        errorMessage: m.errorMessage,
        filesCompleted: m.filesCompleted,
        totalFiles: m.totalFiles,
        downloadedAt: m.downloadedAt,
      );
    }).toList();
    state = state.copyWith(models: models);
  }

  ModelStatus _progressToModelStatus(DownloadStatus ds) {
    switch (ds) {
      case DownloadStatus.queued:
        return ModelStatus.downloading;
      case DownloadStatus.downloading:
        return ModelStatus.downloading;
      case DownloadStatus.extracting: // keep card visible during unzip
        return ModelStatus.downloading;
      case DownloadStatus.paused:
        return ModelStatus.paused;
      case DownloadStatus.completed:
        return ModelStatus.downloaded;
      case DownloadStatus.failed:
        return ModelStatus.error;
      default:
        return ModelStatus.notDownloaded;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subs.values) sub.cancel();
    super.dispose();
  }
}

final modelProvider = StateNotifierProvider<ModelNotifier, ModelState>((ref) {
  final notifier = ModelNotifier(
    ref.watch(downloadManagerProvider),
    ref.watch(cactusServiceProvider),
  );
  notifier.init();
  return notifier;
});

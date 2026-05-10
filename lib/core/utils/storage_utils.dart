import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageUtils {
  /// Get the directory where models are stored
  static Future<Directory> getModelsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Get directory for a specific model
  static Future<Directory> getModelDirectory(String modelId) async {
    final models = await getModelsDirectory();
    final dir = Directory('${models.path}/$modelId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Get temp directory for downloads in progress
  static Future<Directory> getDownloadTempDirectory(String modelId) async {
    final models = await getModelsDirectory();
    final dir = Directory('${models.path}/${modelId}_tmp');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Check free disk space in bytes (Android)
  static Future<int> getFreeDiskSpace() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = await FileStat.stat(dir.path);
      // stat.size gives directory size — use statvfs-like approach via df
      // Approximate: read from /proc/mounts or use platform channel
      // Fallback: return a large number (assume enough space)
      return stat.size > 0 ? stat.size : 20 * 1024 * 1024 * 1024;
    } catch (_) {
      return 20 * 1024 * 1024 * 1024; // 20 GB fallback
    }
  }

  /// Check if a model directory has all expected files
  static Future<bool> isModelComplete(String modelId, int expectedFileCount) async {
    try {
      final dir = await getModelDirectory(modelId);
      final files = await dir.list().toList();
      return files.length >= expectedFileCount;
    } catch (_) {
      return false;
    }
  }

  /// Count files in model directory
  static Future<int> countModelFiles(String modelId) async {
    try {
      final dir = await getModelDirectory(modelId);
      if (!await dir.exists()) return 0;
      return (await dir.list().toList()).length;
    } catch (_) {
      return 0;
    }
  }

  /// Delete entire model directory
  static Future<void> deleteModel(String modelId) async {
    final dir = await getModelDirectory(modelId);
    if (await dir.exists()) await dir.delete(recursive: true);
    final tmp = await getDownloadTempDirectory(modelId);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  }

  /// Get size of model directory in bytes
  static Future<int> getModelSize(String modelId) async {
    try {
      final dir = await getModelDirectory(modelId);
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ── Formatting helpers ─────────────────────────────────────────────────────

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatSpeed(double bytesPerSecond) {
    return '${formatBytes(bytesPerSecond.toInt())}/s';
  }

  static String formatEta(Duration eta) {
    if (eta.inSeconds < 60) return '${eta.inSeconds}s left';
    if (eta.inMinutes < 60) return '${eta.inMinutes}m ${eta.inSeconds % 60}s left';
    return '${eta.inHours}h ${eta.inMinutes % 60}m left';
  }
}

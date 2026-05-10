import 'dart:io';

/// Locates extracted Cactus model bundles.
///
/// Hugging Face repos used by this app contain zip files produced by
/// `cactus convert`. Depending on the model, the extracted bundle may be a
/// single `.cact` file, a config/tokenizer directory, or many sharded weight
/// files with little or no extension metadata.
class CactusModelLocator {
  static const _bundleFileThreshold = 8;

  static Future<bool> hasModel(String dirPath) async {
    return await findModelPath(dirPath) != null;
  }

  /// Returns the path that should be passed to `cactusInit`.
  ///
  /// Directory-format Cactus bundles return their containing directory.
  /// Standalone `.cact`/`.gguf` files return the file path.
  static Future<String?> findModelPath(String dirPath) async {
    final root = Directory(dirPath);
    if (!await root.exists()) return null;

    String? singleFile;
    var sawAnyFile = false;
    final candidates = <String, _CactusBundleProbe>{};

    await for (final entity in root.list(recursive: true)) {
      if (entity is! File) continue;
      sawAnyFile = true;

      final lower = entity.path.toLowerCase();
      final name = _basename(lower);
      final isStandalone = lower.endsWith('.cact') || lower.endsWith('.gguf');
      if (isStandalone) singleFile = entity.path;

      var dir = entity.parent;
      while (_isSameOrWithin(dir.path, root.path)) {
        final probe = candidates.putIfAbsent(dir.path, _CactusBundleProbe.new);
        probe.fileCount++;

        if (name == 'config.json' || name == 'config.txt') {
          probe.hasConfig = true;
        }
        if (_isTokenizerFile(name)) {
          probe.hasTokenizer = true;
        }
        if (_isKnownWeightFile(lower)) {
          probe.hasKnownWeights = true;
          probe.likelyWeightCount++;
        } else if (_isLikelyWeightShard(name)) {
          probe.likelyWeightCount++;
        }

        if (_samePath(dir.path, root.path)) break;
        dir = dir.parent;
      }
    }

    final bundle = _bestBundle(candidates);
    if (bundle != null) return bundle;

    if (singleFile != null) return singleFile;

    // Cactus convert output can be version-dependent. For a non-empty model
    // folder, prefer trying the directory over hiding the existing download.
    if (sawAnyFile) return root.path;

    return null;
  }

  static String? _bestBundle(Map<String, _CactusBundleProbe> candidates) {
    String? bestPath;
    _CactusBundleProbe? bestProbe;

    for (final entry in candidates.entries) {
      final probe = entry.value;
      if (!probe.isValidBundle) continue;

      if (bestProbe == null ||
          probe.score > bestProbe.score ||
          (probe.score == bestProbe.score &&
              _pathDepth(entry.key) > _pathDepth(bestPath!))) {
        bestPath = entry.key;
        bestProbe = probe;
      }
    }

    return bestPath;
  }

  static bool _isTokenizerFile(String name) {
    return name == 'tokenizer.json' ||
        name == 'tokenizer_config.json' ||
        name == 'special_tokens_map.json' ||
        name == 'tokenizer.model';
  }

  static bool _isKnownWeightFile(String lowerPath) {
    return lowerPath.endsWith('.cact') ||
        lowerPath.endsWith('.gguf') ||
        lowerPath.endsWith('.weights') ||
        lowerPath.endsWith('.bin') ||
        lowerPath.endsWith('.safetensors');
  }

  static bool _isLikelyWeightShard(String name) {
    if (name.startsWith('.')) return false;
    if (_isTokenizerFile(name) ||
        name == 'config.json' ||
        name == 'config.txt') {
      return false;
    }
    return !name.endsWith('.json') &&
        !name.endsWith('.txt') &&
        !name.endsWith('.md') &&
        !name.endsWith('.yaml') &&
        !name.endsWith('.yml');
  }

  static bool _isSameOrWithin(String path, String root) {
    return _samePath(path, root) ||
        _normalize(path)
            .startsWith('${_normalize(root)}${Platform.pathSeparator}');
  }

  static bool _samePath(String a, String b) => _normalize(a) == _normalize(b);

  static String _normalize(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  static int _pathDepth(String path) {
    return _normalize(path)
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .length;
  }
}

class _CactusBundleProbe {
  bool hasConfig = false;
  bool hasTokenizer = false;
  bool hasKnownWeights = false;
  int likelyWeightCount = 0;
  int fileCount = 0;

  bool get isValidBundle {
    if (hasConfig &&
        (hasKnownWeights || likelyWeightCount > 0 || hasTokenizer)) {
      return true;
    }

    return likelyWeightCount >= CactusModelLocator._bundleFileThreshold &&
        fileCount >= CactusModelLocator._bundleFileThreshold;
  }

  int get score {
    return (hasConfig ? 1000 : 0) +
        (hasTokenizer ? 200 : 0) +
        (hasKnownWeights ? 100 : 0) +
        likelyWeightCount.clamp(0, 50);
  }
}

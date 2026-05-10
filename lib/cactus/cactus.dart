/// FixGemma Cactus bridge
///
/// Wraps cactus_ffi.dart with a safe probe so the app gracefully falls back
/// to demo mode when libcactus.so is absent. Import ONLY this file.
library cactus;

import 'dart:ffi';
import 'dart:io';

export 'cactus_ffi.dart';

// ── Availability probe ───────────────────────────────────────────────────────

bool get isCactusAvailable => _available;
bool _available = false;
bool _probed = false;

/// Call once before any FFI use. Probes the native library with a real
/// DynamicLibrary.open so we know for certain whether it is present.
void initCactus() {
  if (_probed) return;
  _probed = true;
  try {
    if (Platform.isAndroid) {
      // Try to open the lib — throws ArgumentError/OSError if absent.
      DynamicLibrary.open('libcactus.so');
      _available = true;
    } else if (Platform.isIOS || Platform.isMacOS) {
      DynamicLibrary.process();
      _available = true;
    }
    // Other platforms: stay false (demo mode)
  } catch (_) {
    _available = false;
  }
}

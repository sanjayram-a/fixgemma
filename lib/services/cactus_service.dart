import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import '../core/utils/cactus_model_locator.dart';
import '../cactus/cactus.dart';
import '../models/chat_message.dart';

enum CactusServiceState { idle, loading, ready, error }

/// Wraps the official Cactus Flutter SDK (cactus_ffi.dart) with:
/// - Placeholder/demo mode when libcactus.so is absent
/// - Async/streaming chat interface for Riverpod providers
/// - Graceful error handling
class CactusService {
  CactusModelT? _model;
  CactusServiceState _state = CactusServiceState.idle;
  String? _errorMessage;
  final _stateController = StreamController<CactusServiceState>.broadcast();

  CactusServiceState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isReady => _state == CactusServiceState.ready;
  Stream<CactusServiceState> get stateStream => _stateController.stream;

  void _setState(CactusServiceState s, {String? error}) {
    _state = s;
    _errorMessage = error;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// Load model from a local directory path.
  /// Scans the directory for model files and passes the correct path to cactusInit.
  ///
  /// Cactus models commonly come in these formats:
  ///   1. Single-file: .cact/.gguf -> pass the file path
  ///   2. Directory bundle: config.json/config.txt + tokenizer + weights -> pass the directory path
  ///   3. Cactus convert output: many sharded weight files -> pass the directory path
  Future<void> loadModel(String modelDirPath, {int contextSize = 2048}) async {
    if (_state == CactusServiceState.loading) return;
    _setState(CactusServiceState.loading);

    // Probe library — sets isCactusAvailable
    initCactus();
    print('[CactusService] isCactusAvailable=$isCactusAvailable');

    if (!isCactusAvailable) {
      // Demo mode — simulate a 1-second "load"
      print('[CactusService] Demo mode — simulating load');
      await Future.delayed(const Duration(seconds: 1));
      _setState(CactusServiceState.ready);
      return;
    }

    // Find the actual model path (file or directory)
    final modelPath = await _findModelPath(modelDirPath);
    print('[CactusService] modelPath=$modelPath');
    if (modelPath == null) {
      _setState(CactusServiceState.error,
          error: 'No model files found in $modelDirPath. '
              'The downloaded zip may not have extracted correctly.');
      return;
    }

    try {
      print('[CactusService] Calling cactusInit in background isolate...');
      final modelAddress = await Isolate.run(() {
        final model = cactusInit(modelPath, null, false);
        return model.address;
      });
      _model = Pointer<Void>.fromAddress(modelAddress);
      print('[CactusService] cactusInit completed, model=$_model');
      _setState(CactusServiceState.ready);
    } catch (e) {
      print('[CactusService] cactusInit FAILED: $e');
      _setState(CactusServiceState.error, error: e.toString());
    }
  }

  /// Finds the correct path to pass to cactusInit.
  ///
  /// For directory-format models, returns the directory containing the bundle.
  /// For single-file models (.cact/.gguf), returns the file path.
  static Future<String?> _findModelPath(String dirPath) async {
    return CactusModelLocator.findModelPath(dirPath);
  }

  /// Stream chat completion tokens.
  Stream<String> chat(
    List<AppMessage> messages, {
    int maxTokens = 512,
    double temperature = 0.7,
    String? systemPrompt,
  }) async* {
    if (!isReady) {
      print('[CactusService] chat() called but not ready (state=$_state)');
      yield 'Model is not ready yet. Please wait.';
      return;
    }

    // Demo mode
    if (!isCactusAvailable || _model == null) {
      print('[CactusService] chat() using mock stream');
      yield* _mockStream(messages.last.content);
      return;
    }

    final allMessages = <Map<String, dynamic>>[];
    if (systemPrompt != null) {
      allMessages.add({'role': 'system', 'content': systemPrompt});
    }
    allMessages.addAll(messages.map((m) => m.toCactusJson()));

    final messagesJson = jsonEncode(allMessages);
    final optionsJson = jsonEncode({
      'max_tokens': maxTokens,
      'temperature': temperature,
    });

    print('[CactusService] Starting cactusComplete in background isolate...');

    try {
      // Stream tokens from a background isolate so the UI stays responsive.
      // Native heap memory is shared across isolates, so the model pointer
      // can be reconstructed from its address in the child isolate.
      final receivePort = ReceivePort();

      await Isolate.spawn(
        _completeInIsolate,
        _IsolateArgs(
          sendPort: receivePort.sendPort,
          modelAddress: _model!.address,
          messagesJson: messagesJson,
          optionsJson: optionsJson,
        ),
      );

      await for (final msg in receivePort) {
        if (msg == null) {
          // null = completion finished
          break;
        } else if (msg is String) {
          yield msg;
        } else if (msg is Map && msg.containsKey('error')) {
          yield '\n\n*Error: ${msg['error']}*';
          break;
        }
      }
      receivePort.close();
      print('[CactusService] cactusComplete finished');
    } catch (e) {
      print('[CactusService] cactusComplete error: $e');
      yield 'Error: $e';
    }
  }

  /// Transcribe audio from a file path.
  /// Official API: cactusTranscribe(model, audioPath, prompt, optionsJson, onToken, pcmData)
  Future<String?> transcribeAudio(String audioPath) async {
    if (!isReady) return null;
    if (!isCactusAvailable || _model == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      return 'Voice message received';
    }
    try {
      final resultJson = await Future.microtask(
        () => cactusTranscribe(_model!, audioPath, null, null, null, null),
      );
      // Result is JSON: {"text": "...", "segments": [...]}
      final parsed = jsonDecode(resultJson) as Map<String, dynamic>;
      return parsed['text'] as String? ?? resultJson;
    } catch (e) {
      return null;
    }
  }

  void resetConversation() {
    if (_model != null && isCactusAvailable) {
      cactusReset(_model!);
    }
  }

  void stopGeneration() {
    if (_model != null && isCactusAvailable) {
      cactusStop(_model!);
    }
  }

  void unloadModel() {
    if (_model != null && isCactusAvailable) {
      cactusDestroy(_model!);
      _model = null;
    }
    _setState(CactusServiceState.idle);
  }

  void dispose() {
    unloadModel();
    _stateController.close();
  }

  // ── Demo / placeholder responses ──────────────────────────────────────────
  Stream<String> _mockStream(String userInput) async* {
    final lower = userInput.toLowerCase();
    String response;

    if (lower.contains('washing machine') || lower.contains('washer')) {
      response = '''**Washing Machine Troubleshooting** 🔧

Here are the most common fixes:

**Not draining?**
1. Check the drain hose for kinks or blockages
2. Clean the pump filter (small panel at the bottom front)
3. Check if the lid/door switch is working

**Not spinning?**
1. Redistribute clothes — unbalanced load stops spin
2. Check the drive belt (unplug first, then inspect)
3. Motor coupling may be worn out

**Making noise?**
1. Foreign objects (coins, buttons) in the drum or pump
2. Bearings failing — grinding during spin

Tell me the brand and error code for more specific help.''';
    } else if (lower.contains('fridge') || lower.contains('refrigerator')) {
      response = '''**Refrigerator Troubleshooting** ❄️

**Not cooling?**
1. Clean condenser coils — dusty coils = poor cooling
2. Make sure the condenser fan is spinning
3. Check door seals — a dollar bill should resist when door closes
4. Ensure vents inside aren't blocked by food

**Frosted over?**
Evaporator coils may be iced up. Unplug for 24-48 hours with doors open.

**Leaking water?**
- Defrost drain tube clogged — clear with warm water
- Check water supply line connections

What's your specific symptom?''';
    } else if (lower.contains('dishwasher')) {
      response = '''**Dishwasher Troubleshooting** 🍽️

**Not cleaning properly?**
1. Check and clean the filter at the bottom
2. Make sure spray arms spin freely and holes aren't clogged
3. Use the correct amount of detergent — too much causes buildup

**Not draining?**
1. Clean the filter
2. Check the drain hose for kinks
3. Ensure the air gap (if fitted) isn't blocked

**Door not latching?**
The door latch mechanism may be worn — usually an easy DIY fix.''';
    } else {
      response =
          '''Hi! I'm **FixGemma** 🔧 — your on-device AI repair assistant.

I can help you troubleshoot and fix:
- **Washing machines & dryers**
- **Refrigerators & freezers**
- **Dishwashers**
- **Ovens & microwaves**
- **Small appliances**

Describe what's wrong — or take a photo of the issue and I'll diagnose it step by step!

> 💡 *Note: Running in demo mode. Download the model from the home screen for full AI assistance.*''';
    }

    // Stream word-by-word
    final words = response.split(' ');
    for (final word in words) {
      yield '$word ';
      await Future.delayed(const Duration(milliseconds: 35));
    }
  }
}

// ── Isolate helpers for background inference ──────────────────────────────────

/// Arguments passed to the background isolate for cactusComplete.
class _IsolateArgs {
  final SendPort sendPort;
  final int modelAddress;
  final String messagesJson;
  final String optionsJson;

  const _IsolateArgs({
    required this.sendPort,
    required this.modelAddress,
    required this.messagesJson,
    required this.optionsJson,
  });
}

/// Runs cactusComplete in a background isolate.
/// Sends each token as a String via [sendPort], and null when done.
void _completeInIsolate(_IsolateArgs args) {
  try {
    // Reconstruct the model pointer from its address.
    // Native heap memory is shared across all isolates in the same process.
    final model = Pointer<Void>.fromAddress(args.modelAddress);

    cactusComplete(
      model,
      args.messagesJson,
      args.optionsJson,
      null, // toolsJson
      (token, _) => args.sendPort.send(token),
    );

    // Signal completion
    args.sendPort.send(null);
  } catch (e) {
    args.sendPort.send({'error': e.toString()});
  }
}

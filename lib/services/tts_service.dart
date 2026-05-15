import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class TtsService {
  final _tts = FlutterTts();
  final Completer<void> _initCompleter = Completer<void>();
  bool _initialized = false;
  bool _isEnabled = true;
  bool _isSpeaking = false;
  double _speechRate = 0.55;

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  double get speechRate => _speechRate;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await init();
    await _initCompleter.future;
  }

  Future<void> speak(String text) async {
    await _ensureInit();
    if (!_isEnabled) return;
    await _tts.stop();
    _isSpeaking = false;
    // Strip markdown for cleaner speech
    final clean = text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
        .replaceAll('```', '')
        .trim();
    if (clean.isEmpty) return;
    await _tts.speak(clean);
  }

  Future<void> stop() async {
    await _ensureInit();
    await _tts.stop();
    _isSpeaking = false;
  }

  void setEnabled(bool val) {
    _isEnabled = val;
    if (!val) {
      _tts.stop();
      _isSpeaking = false;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await _ensureInit();
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  void dispose() {
    _tts.stop();
    _isSpeaking = false;
  }
}

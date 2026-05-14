import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final _tts = FlutterTts();
  bool _isEnabled = true;
  bool _isSpeaking = false;
  double _speechRate = 0.55;

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  double get speechRate => _speechRate;

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  Future<void> speak(String text) async {
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
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  void dispose() {
    _tts.stop();
    _isSpeaking = false;
  }
}

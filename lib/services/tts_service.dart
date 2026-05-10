import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final _tts = FlutterTts();
  bool _isEnabled = true;
  double _speechRate = 0.55;

  bool get isEnabled => _isEnabled;
  double get speechRate => _speechRate;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (!_isEnabled) return;
    await _tts.stop();
    // Strip markdown for cleaner speech
    final clean = text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
        .replaceAll('```', '')
        .trim();
    await _tts.speak(clean);
  }

  Future<void> stop() async => await _tts.stop();

  void setEnabled(bool val) {
    _isEnabled = val;
    if (!val) _tts.stop();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  void dispose() => _tts.stop();
}

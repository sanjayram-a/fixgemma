import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission(request: true);
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    final dir = await getTemporaryDirectory();
    _currentPath =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: _currentPath!,
    );
    _isRecording = true;
  }

  /// Stop recording and return the file path, or null on error
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
      // Delete temp file
      if (_currentPath != null) {
        final f = File(_currentPath!);
        if (await f.exists()) await f.delete();
      }
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

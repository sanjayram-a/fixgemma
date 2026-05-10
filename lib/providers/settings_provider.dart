import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool ttsEnabled;
  final bool autoSpeak;
  final double speechRate;
  final bool darkMode; // always dark for now
  final int contextSize;
  final String? hfToken;

  const AppSettings({
    this.ttsEnabled = false,
    this.autoSpeak = false,
    this.speechRate = 0.55,
    this.darkMode = true,
    this.contextSize = 2048,
    this.hfToken,
  });

  bool get hasHfToken => hfToken != null && hfToken!.trim().isNotEmpty;

  AppSettings copyWith({
    bool? ttsEnabled,
    bool? autoSpeak,
    double? speechRate,
    bool? darkMode,
    int? contextSize,
    String? hfToken,
    bool clearHfToken = false,
  }) =>
      AppSettings(
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        speechRate: speechRate ?? this.speechRate,
        darkMode: darkMode ?? this.darkMode,
        contextSize: contextSize ?? this.contextSize,
        hfToken: clearHfToken ? null : hfToken ?? this.hfToken,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      ttsEnabled: prefs.getBool('tts_enabled') ?? false,
      autoSpeak: prefs.getBool('auto_speak') ?? false,
      speechRate: prefs.getDouble('speech_rate') ?? 0.55,
      contextSize: prefs.getInt('context_size') ?? 2048,
      hfToken: prefs.getString('hf_token'),
    );
  }

  Future<void> setTtsEnabled(bool v) async {
    state = state.copyWith(ttsEnabled: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('tts_enabled', v);
  }

  Future<void> setAutoSpeak(bool v) async {
    state = state.copyWith(autoSpeak: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('auto_speak', v);
  }

  Future<void> setSpeechRate(double v) async {
    state = state.copyWith(speechRate: v);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('speech_rate', v);
  }

  Future<void> setContextSize(int v) async {
    state = state.copyWith(contextSize: v);
    final p = await SharedPreferences.getInstance();
    await p.setInt('context_size', v);
  }

  Future<void> setHfToken(String v) async {
    final token = v.trim();
    final p = await SharedPreferences.getInstance();
    if (token.isEmpty) {
      state = state.copyWith(clearHfToken: true);
      await p.remove('hf_token');
      return;
    }

    state = state.copyWith(hfToken: token);
    await p.setString('hf_token', token);
  }

  Future<void> clearHfToken() => setHfToken('');
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

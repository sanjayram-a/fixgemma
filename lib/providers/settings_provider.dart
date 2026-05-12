import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool ttsEnabled;
  final bool autoSpeak;
  final double speechRate;
  final bool darkMode;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final String? hfToken;

  const AppSettings({
    this.ttsEnabled = false,
    this.autoSpeak = false,
    this.speechRate = 0.55,
    this.darkMode = false,
    this.maxTokens = 2048,
    this.temperature = 1.0,
    this.topP = 0.95,
    this.topK = 64,
    this.hfToken,
  });

  bool get hasHfToken => hfToken != null && hfToken!.trim().isNotEmpty;

  AppSettings copyWith({
    bool? ttsEnabled,
    bool? autoSpeak,
    double? speechRate,
    bool? darkMode,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? topK,
    String? hfToken,
    bool clearHfToken = false,
  }) =>
      AppSettings(
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        speechRate: speechRate ?? this.speechRate,
        darkMode: darkMode ?? this.darkMode,
        maxTokens: maxTokens ?? this.maxTokens,
        temperature: temperature ?? this.temperature,
        topP: topP ?? this.topP,
        topK: topK ?? this.topK,
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
      maxTokens: prefs.getInt('max_tokens') ?? 2048,
      temperature: prefs.getDouble('temperature') ?? 1.0,
      topP: prefs.getDouble('top_p') ?? 0.95,
      topK: prefs.getInt('top_k') ?? 64,
      hfToken: prefs.getString('hf_token'),
    );
  }

  Future<void> setTtsEnabled(bool v) async {
    state = state.copyWith(ttsEnabled: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('tts_enabled', v);
  }

  Future<void> setSpeechRate(double v) async {
    state = state.copyWith(speechRate: v);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('speech_rate', v);
  }

  Future<void> setMaxTokens(int v) async {
    state = state.copyWith(maxTokens: v);
    final p = await SharedPreferences.getInstance();
    await p.setInt('max_tokens', v);
  }

  Future<void> setTemperature(double v) async {
    state = state.copyWith(temperature: v);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('temperature', v);
  }

  Future<void> setTopP(double v) async {
    state = state.copyWith(topP: v);
    final p = await SharedPreferences.getInstance();
    await p.setDouble('top_p', v);
  }

  Future<void> setTopK(int v) async {
    state = state.copyWith(topK: v);
    final p = await SharedPreferences.getInstance();
    await p.setInt('top_k', v);
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

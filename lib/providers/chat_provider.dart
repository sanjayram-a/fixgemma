import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/cactus_service.dart';
import '../services/chat_storage.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import 'model_provider.dart';
import 'settings_provider.dart';

const _uuid = Uuid();

// ── Service providers ──────────────────────────────────────────────────────
final chatStorageProvider = Provider<ChatStorage>((ref) {
  return ChatStorage();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final svc = AudioService();
  ref.onDispose(svc.dispose);
  return svc;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  final svc = TtsService();
  svc.init();
  ref.onDispose(svc.dispose);
  return svc;
});

// ── Chat State ─────────────────────────────────────────────────────────────
class ChatState {
  final ChatSession? activeSession;
  final List<AppMessage> messages;
  final bool isStreaming;
  final bool isLoadingModel;
  final String? streamingText;
  final String? errorMessage;
  final bool isRecording;

  const ChatState({
    this.activeSession,
    this.messages = const [],
    this.isStreaming = false,
    this.isLoadingModel = false,
    this.streamingText,
    this.errorMessage,
    this.isRecording = false,
  });

  ChatState copyWith({
    ChatSession? activeSession,
    List<AppMessage>? messages,
    bool? isStreaming,
    bool? isLoadingModel,
    String? streamingText,
    String? errorMessage,
    bool? isRecording,
  }) =>
      ChatState(
        activeSession: activeSession ?? this.activeSession,
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        isLoadingModel: isLoadingModel ?? this.isLoadingModel,
        streamingText: streamingText ?? this.streamingText,
        errorMessage: errorMessage ?? this.errorMessage,
        isRecording: isRecording ?? this.isRecording,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final CactusService _cactus;
  final ChatStorage _storage;
  final AudioService _audio;
  final TtsService _tts;
  final String? _activeModelId;
  final bool _ttsEnabled;

  ChatNotifier(this._cactus, this._storage, this._audio, this._tts,
      this._activeModelId, this._ttsEnabled)
      : super(const ChatState());

  static const String _systemPrompt =
      'You are FixGemma, an expert appliance repair and DIY assistant. '
      'Give clear, step-by-step guidance for diagnosing and fixing household appliances. '
      'Always prioritize safety — warn about electrical hazards or when to call a professional. '
      'Keep responses practical and easy to follow for someone with basic DIY skills. '
      'Use markdown for structure when it helps clarity.'
      'Always Answer in User Language';

  /// Start a new chat session
  Future<void> newChat() async {
    // Stop any active generation first
    if (state.isStreaming) {
      _cactus.stopGeneration();
    }

    final modelId = _activeModelId ?? 'fixgemma4-e4b-int4';
    final session = await _storage.createSession(modelId);
    if (!mounted) return;
    _cactus.resetConversation();
    state = state.copyWith(
      activeSession: session,
      messages: [],
      isStreaming: false,
      streamingText: null,
      errorMessage: null,
    );
  }

  /// Load an existing session
  Future<void> loadSession(ChatSession session) async {
    _cactus.resetConversation();
    state = state.copyWith(
      activeSession: session,
      messages: List.from(session.messages),
      streamingText: null,
    );
  }

  /// Send a text message (optionally with images / audio)
  Future<void> sendMessage(String text,
      {List<String>? imagePaths, String? audioPath}) async {
    if (state.isStreaming) return;

    final hasImages = imagePaths != null && imagePaths.isNotEmpty;
    final hasAudio = audioPath != null;
    if (text.trim().isEmpty && !hasImages && !hasAudio) return;

    // If user sends only images with no text, provide context
    if (text.trim().isEmpty && hasImages) {
      text = 'What\'s wrong with this? Please diagnose the issue.';
    }

    // Ensure we have an active session
    if (state.activeSession == null) await newChat();
    if (!mounted) return;

    final userMsg = AppMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      imagePaths: imagePaths,
      audioPath: audioPath,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: updatedMessages, isStreaming: true, streamingText: '');

    // Create placeholder assistant message
    final assistantMsg = AppMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...updatedMessages, assistantMsg]);

    // Stream response
    final buffer = StringBuffer();
    try {
      await for (final token in _cactus.chat(
        updatedMessages,
        systemPrompt: _systemPrompt,
        maxTokens: 1024,
        temperature: 0.7,
      )) {
        if (!mounted) return;
        buffer.write(token);
        final newMessages = List<AppMessage>.from(state.messages);
        newMessages.last = assistantMsg.copyWith(
            content: buffer.toString(), isStreaming: true);
        state = state.copyWith(messages: newMessages, streamingText: buffer.toString());
      }
    } catch (e) {
      buffer.write('\n\n*Error: ${e.toString()}*');
    }

    if (!mounted) return;

    // Finalize
    final finalMessages = List<AppMessage>.from(state.messages);
    finalMessages.last =
        assistantMsg.copyWith(content: buffer.toString(), isStreaming: false);

    state = state.copyWith(
      messages: finalMessages,
      isStreaming: false,
      streamingText: null,
    );

    // Save session
    if (state.activeSession != null) {
      state.activeSession!.messages.clear();
      state.activeSession!.messages.addAll(finalMessages);
      await _storage.saveSession(state.activeSession!);
    }

    // TTS
    if (mounted && _ttsEnabled && buffer.isNotEmpty) {
      await _tts.speak(buffer.toString());
    }
  }

  /// Record voice, transcribe, then send
  Future<void> startVoiceRecording() async {
    final hasPerms = await _audio.hasPermission();
    if (!hasPerms) {
      state = state.copyWith(
          errorMessage: 'Microphone permission denied. Please enable in Settings.');
      return;
    }
    await _audio.startRecording();
    state = state.copyWith(isRecording: true);
  }

  Future<void> stopVoiceRecording() async {
    if (!state.isRecording) return;
    final path = await _audio.stopRecording();
    if (!mounted) return;
    state = state.copyWith(isRecording: false);

    if (path == null) return;

    // Gemma 4 E4B supports native audio input via cactusComplete.
    // Pass the audio file path directly in the message — toCactusJson()
    // adds "audio": [path] which cactusComplete handles natively.
    // Do NOT call cactusTranscribe (that's for dedicated STT models).
    await sendMessage('🎤 Voice message', audioPath: path);
  }

  void clearError() => state = state.copyWith(errorMessage: null);
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final cactus = ref.watch(cactusServiceProvider);
  final storage = ref.watch(chatStorageProvider);
  final audio = ref.watch(audioServiceProvider);
  final tts = ref.watch(ttsServiceProvider);
  // Use ref.read (not watch) for model/settings to avoid re-creating
  // the ChatNotifier mid-stream when these providers update.
  final modelState = ref.read(modelProvider);
  final settings = ref.read(settingsProvider);

  return ChatNotifier(
      cactus, storage, audio, tts, modelState.activeModelId, settings.ttsEnabled);
});

// ── Sessions list ──────────────────────────────────────────────────────────
final sessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final storage = ref.watch(chatStorageProvider);
  return storage.getAllSessions();
});

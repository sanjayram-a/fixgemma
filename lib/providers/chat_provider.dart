import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/repair_response.dart';
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

  final initialSettings = ref.read(settingsProvider);
  svc.setEnabled(initialSettings.ttsEnabled);
  unawaited(svc.setSpeechRate(initialSettings.speechRate));

  ref.listen<AppSettings>(settingsProvider, (_, next) {
    svc.setEnabled(next.ttsEnabled);
    unawaited(svc.setSpeechRate(next.speechRate));
  });

  ref.onDispose(svc.dispose);
  return svc;
});

// ── Repair Card State ──────────────────────────────────────────────────────
/// Represents one "card" shown in the response carousel.
enum RepairCardType { safety, tools, step, tips, userPrompt, followUp }

class RepairCard {
  final RepairCardType type;
  final String title;
  final String body;
  final bool isLoading;

  const RepairCard({
    required this.type,
    required this.title,
    required this.body,
    this.isLoading = false,
  });

  RepairCard copyWith({String? body, bool? isLoading}) => RepairCard(
        type: type,
        title: title,
        body: body ?? this.body,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Chat State ─────────────────────────────────────────────────────────────
class ChatState {
  static const Object _unset = Object();

  final ChatSession? activeSession;
  final List<AppMessage> messages;
  final bool isStreaming;
  final bool isLoadingModel;
  final String? streamingText;
  final String? errorMessage;
  final bool isRecording;
  final int? autoTtsCardIndex;

  // Structured response data
  final List<RepairCard> cards;
  final RepairResponse? lastResponse;
  final Map<String, dynamic>? lastInferenceMeta;

  const ChatState({
    this.activeSession,
    this.messages = const [],
    this.isStreaming = false,
    this.isLoadingModel = false,
    this.streamingText,
    this.errorMessage,
    this.isRecording = false,
    this.autoTtsCardIndex,
    this.cards = const [],
    this.lastResponse,
    this.lastInferenceMeta,
  });

  ChatState copyWith({
    Object? activeSession = _unset,
    List<AppMessage>? messages,
    bool? isStreaming,
    bool? isLoadingModel,
    Object? streamingText = _unset,
    Object? errorMessage = _unset,
    bool? isRecording,
    Object? autoTtsCardIndex = _unset,
    List<RepairCard>? cards,
    Object? lastResponse = _unset,
    Object? lastInferenceMeta = _unset,
  }) =>
      ChatState(
        activeSession: identical(activeSession, _unset)
            ? this.activeSession
            : activeSession as ChatSession?,
        messages: messages ?? this.messages,
        isStreaming: isStreaming ?? this.isStreaming,
        isLoadingModel: isLoadingModel ?? this.isLoadingModel,
        streamingText: identical(streamingText, _unset)
            ? this.streamingText
            : streamingText as String?,
        errorMessage: identical(errorMessage, _unset)
            ? this.errorMessage
            : errorMessage as String?,
        isRecording: isRecording ?? this.isRecording,
        autoTtsCardIndex: identical(autoTtsCardIndex, _unset)
            ? this.autoTtsCardIndex
            : autoTtsCardIndex as int?,
        cards: cards ?? this.cards,
        lastResponse: identical(lastResponse, _unset)
            ? this.lastResponse
            : lastResponse as RepairResponse?,
        lastInferenceMeta: identical(lastInferenceMeta, _unset)
            ? this.lastInferenceMeta
            : lastInferenceMeta as Map<String, dynamic>?,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final CactusService _cactus;
  final ChatStorage _storage;
  final AudioService _audio;
  final TtsService _tts;
  final String? _activeModelId;
  final AppSettings Function() _getSettings;
  int _ttsPlaybackGeneration = 0;

  ChatNotifier(this._cactus, this._storage, this._audio, this._tts,
      this._activeModelId, this._getSettings)
      : super(const ChatState());

  Future<void> stopTtsPlayback() async {
    _ttsPlaybackGeneration++;
    if (mounted) {
      state = state.copyWith(autoTtsCardIndex: null);
    }
    await _tts.stop();
  }

  Future<void> speakText(String text) async {
    if (!_tts.isEnabled) return;
    _ttsPlaybackGeneration++;
    final normalized = _normalizeTtsText(text);
    if (normalized.isEmpty) return;
    await _tts.speak(normalized);
  }

  String _normalizeTtsText(String text) {
    return text
        .replaceAll('•', '')
        .replaceAll('⚠️', 'Warning.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _speakCardsSequentially(
    List<RepairCard> cards, {
    required int baseOffset,
    required bool enabled,
  }) async {
    if (!enabled) return;
    final runId = ++_ttsPlaybackGeneration;

    for (int i = 0; i < cards.length; i++) {
      if (runId != _ttsPlaybackGeneration) break;
      final liveSettings = _getSettings();
      if (!liveSettings.ttsEnabled) break;

      final card = cards[i];
      if (card.type == RepairCardType.followUp ||
          card.type == RepairCardType.userPrompt ||
          card.isLoading) {
        continue;
      }

      final combined = _normalizeTtsText('${card.title}. ${card.body}');
      if (combined.isEmpty) continue;

      if (mounted) {
        state = state.copyWith(autoTtsCardIndex: baseOffset + i);
      }
      await _tts.speak(combined);
    }

    if (mounted && runId == _ttsPlaybackGeneration) {
      state = state.copyWith(autoTtsCardIndex: null);
    }
  }

  // Structured JSON system prompt — optimised for small quantised mobile models
  static const String _systemPrompt =
      'You are fixgemma ,a master technician and home repair expert. You provide clear, step-by-step instructions for fixing devices, appliances, and home items.'
      'Always respond in the exact same language the user writes in. '
      'CRITICAL: Output ONLY raw, valid JSON. '
      'Do not include markdown formatting like ```json or any text before or after the JSON.\n\n'
      'Use this exact JSON structure:\n'
      '{\n'
      '  "safety": "<safety message>",\n'
      '  "tools": ["<tool 1>", "<tool 2>"],\n'
      '  "steps": [\n'
      '    {"number": 1, "title": "<title>", "description": "<description>", "warning": "<warning>"}\n'
      '  ],\n'
      '  "tips": ["<tip 1>"]\n'
      '}\n\n'
      'Rules:\n'
      '- If there are no safety hazards, set "safety" to "".\n'
      '- If no tools are needed, set "tools" to [].\n'
      '- If there are no extra tips, set "tips" to [].\n'
      '- If a step has no warning, set "warning" to "".\n'
      '- NEVER use the value null. Always use "" or [] instead.\n'
      '- Always include at least one step in the "steps" array.';

  /// Start a new repair session with a prompt
  Future<void> newChat() async {
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
      cards: [],
      lastResponse: null,
      lastInferenceMeta: null,
      autoTtsCardIndex: null,
    );
  }

  /// Load an existing session
  Future<void> loadSession(ChatSession session) async {
    _cactus.resetConversation();
    final messages = List<AppMessage>.from(session.messages);
    final assistantMessages = messages
        .where((m) => m.isAssistant && m.content.trim().isNotEmpty)
        .toList();

    final hydratedCards = <RepairCard>[];
    RepairResponse? hydratedLastResponse;

    for (final assistant in assistantMessages) {
      final parser = RepairResponseParser();
      parser.feed(assistant.content);
      final parsed = parser.finalize();
      final cards = _buildCards(
        parsed,
        isGenerating: false,
        rawBuffer: assistant.content,
      );
      if (cards.isNotEmpty) {
        hydratedCards.addAll(cards);
        hydratedLastResponse = parsed;
      }
    }

    if (hydratedCards.isNotEmpty) {
      hydratedCards.add(const RepairCard(
        type: RepairCardType.followUp,
        title: 'Any Questions?',
        body: '',
      ));
    }

    state = state.copyWith(
      activeSession: session,
      messages: messages,
      streamingText: null,
      errorMessage: null,
      isStreaming: false,
      cards: hydratedCards,
      lastResponse: hydratedLastResponse,
      lastInferenceMeta: null,
      autoTtsCardIndex: null,
    );
  }

  /// Send a message and stream structured JSON response.
  /// If [appendTo] is provided, new cards are appended after those cards
  /// (used for follow-up questions in the same carousel).
  Future<void> sendMessage(
    String text, {
    List<String>? imagePaths,
    String? audioPath,
    List<RepairCard>? appendTo,
  }) async {
    if (state.isStreaming) return;

    final hasImages = imagePaths != null && imagePaths.isNotEmpty;
    final hasAudio = audioPath != null;
    if (text.trim().isEmpty && !hasImages && !hasAudio) return;

    if (text.trim().isEmpty && hasAudio && hasImages) {
      text =
          'Please diagnose this issue using my attached voice note and image.';
    } else if (text.trim().isEmpty && hasAudio) {
      text = 'Voice input. Please transcribe and provide repair guidance.';
    } else if (text.trim().isEmpty && hasImages) {
      text = "What's wrong with this? Please diagnose the issue.";
    }

    if (state.activeSession == null) await newChat();
    if (!mounted) return;

    final followUpPromptCard = appendTo != null && appendTo.isNotEmpty
        ? RepairCard(
            type: RepairCardType.userPrompt,
            title: 'Follow-up Question',
            body: text.trim(),
          )
        : null;

    final userMsg = AppMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text.trim(),
      imagePaths: imagePaths,
      audioPath: audioPath,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg];
    final modelMessages =
        _messagesForModel(updatedMessages, appendTo: appendTo);
    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: true,
      streamingText: '',
      lastInferenceMeta: null,
    );

    // Create placeholder assistant message
    final assistantMsg = AppMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...updatedMessages, assistantMsg]);

    // Stream and parse response
    final parser = RepairResponseParser();
    final buffer = StringBuffer();
    final settings = _getSettings();
    final useHybrid = settings.inferenceMode == InferenceMode.cloudAndLocal;
    _tts.setEnabled(settings.ttsEnabled);
    await _tts.setSpeechRate(settings.speechRate);
    await stopTtsPlayback();

    try {
      await for (final token in _cactus.chat(
        modelMessages,
        systemPrompt: _systemPrompt,
        maxTokens: settings.maxTokens,
        temperature: settings.temperature,
        topP: settings.topP,
        topK: settings.topK,
        completionMode: useHybrid ? 'hybrid' : 'local',
        cactusToken: useHybrid
            ? settings.cactusToken?.trim().isNotEmpty == true
                ? settings.cactusToken!.trim()
                : null
            : null,
      )) {
        if (!mounted) return;
        buffer.write(token);

        final response = parser.feed(token);
        // Pass the raw buffer so _buildCards can extract in-progress step text
        final freshCards = _buildCards(
          response,
          rawBuffer: buffer.toString(),
          isGenerating: true,
        );
        final cards = appendTo != null
            ? <RepairCard>[
                ...appendTo,
                if (followUpPromptCard != null) followUpPromptCard,
                ...freshCards,
              ]
            : freshCards;

        final newMessages = List<AppMessage>.from(state.messages);
        newMessages.last = assistantMsg.copyWith(
          content: buffer.toString(),
          isStreaming: true,
        );

        state = state.copyWith(
          messages: newMessages,
          streamingText: buffer.toString(),
          cards: cards,
          lastResponse: response,
        );
      }
    } catch (e) {
      buffer.write('\n[Error: ${e.toString()}]');
    }

    if (!mounted) return;

    // Final parse
    final finalResponse = parser.finalize();
    final freshFinal = _buildCards(
      finalResponse,
      rawBuffer: buffer.toString(),
      isGenerating: false,
    );
    // Append follow-up card only on the first generation (not on follow-ups)
    final allCards = <RepairCard>[
      ...(appendTo ?? <RepairCard>[]),
      if (followUpPromptCard != null) followUpPromptCard,
      ...freshFinal,
      const RepairCard(
        type: RepairCardType.followUp,
        title: 'Any Questions?',
        body: '',
      ),
    ];

    final finalMessages = List<AppMessage>.from(state.messages);
    finalMessages.last = assistantMsg.copyWith(
      content: buffer.toString(),
      isStreaming: false,
    );

    state = state.copyWith(
      messages: finalMessages,
      isStreaming: false,
      streamingText: null,
      cards: allCards,
      lastResponse: finalResponse,
      lastInferenceMeta: _cactus.lastCompletionMeta,
      autoTtsCardIndex: state.autoTtsCardIndex,
    );

    // Save session immediately after generation
    if (state.activeSession != null) {
      state.activeSession!.messages.clear();
      state.activeSession!.messages.addAll(finalMessages);
      await _storage.saveSession(state.activeSession!);
    }

    await _speakCardsSequentially(
      freshFinal,
      baseOffset:
          (appendTo?.length ?? 0) + (followUpPromptCard != null ? 1 : 0),
      enabled: settings.ttsEnabled,
    );
  }

  List<AppMessage> _messagesForModel(
    List<AppMessage> messages, {
    List<RepairCard>? appendTo,
  }) {
    if (appendTo == null || appendTo.isEmpty) return messages;

    final context = appendTo
        .where((c) => c.type != RepairCardType.followUp)
        .map((c) => '${c.title}: ${c.body}')
        .join('\n\n')
        .trim();
    if (context.isEmpty) return messages;

    final trimmedContext = context.length > 3000
        ? context.substring(context.length - 3000)
        : context;

    final contextMsg = AppMessage(
      id: _uuid.v4(),
      role: 'system',
      content:
          'Continue the same repair conversation. Use this previous guidance as context:\n$trimmedContext',
      timestamp: DateTime.now(),
    );

    final out = List<AppMessage>.from(messages);
    final insertAt = out.isEmpty ? 0 : out.length - 1;
    out.insert(insertAt, contextMsg);
    return out;
  }

  /// Build the cards list from the current parsed response.
  /// [rawBuffer] is used to extract the partial body of the step currently
  /// being streamed (whose closing brace hasn't arrived yet).
  List<RepairCard> _buildCards(
    RepairResponse response, {
    required bool isGenerating,
    String rawBuffer = '',
  }) {
    final cards = <RepairCard>[];

    // Safety card
    if (response.safetyMessage != null &&
        response.safetyMessage!.trim().isNotEmpty) {
      cards.add(RepairCard(
        type: RepairCardType.safety,
        title: '⚠️ Safety First',
        body: response.safetyMessage!,
      ));
    }

    // Tools card
    if (response.toolsRequired != null && response.toolsRequired!.isNotEmpty) {
      cards.add(RepairCard(
        type: RepairCardType.tools,
        title: '🔧 Tools Required',
        body: response.toolsRequired!.map((t) => '• $t').join('\n'),
      ));
    }

    // Complete step cards
    for (final step in response.steps) {
      cards.add(RepairCard(
        type: RepairCardType.step,
        title: 'Step ${step.number}: ${step.title}',
        body: step.description +
            (step.warning != null && step.warning!.trim().isNotEmpty
                ? '\n\n⚠️ ${step.warning}'
                : ''),
      ));
    }

    // If still streaming, try to show the partial step being written right now
    if (isGenerating && rawBuffer.isNotEmpty) {
      final partial = _extractPartialStep(rawBuffer, response.steps.length);
      if (partial != null) {
        // Replace the loading card with a live-updating step card
        cards.add(RepairCard(
          type: RepairCardType.step,
          title: partial.title.isNotEmpty
              ? 'Step ${partial.number}: ${partial.title}'
              : 'Step ${response.steps.length + 1}…',
          body: partial.description.isNotEmpty ? partial.description : '…',
          isLoading: partial.description.isEmpty,
        ));
      } else if (cards.isNotEmpty) {
        // Generic loading card after last completed card
        cards.add(const RepairCard(
          type: RepairCardType.step,
          title: '',
          body: '',
          isLoading: true,
        ));
      }
    }

    // Tips card
    if (response.tips != null && response.tips!.isNotEmpty) {
      cards.add(RepairCard(
        type: RepairCardType.tips,
        title: '💡 Tips',
        body: response.tips!.map((t) => '• $t').join('\n'),
      ));
    }

    return cards;
  }

  /// Extract the step object currently being streamed (not yet complete).
  /// Returns null if no partial step is found or all steps are already complete.
  _PartialStep? _extractPartialStep(String raw, int completedSteps) {
    // Find the steps array
    final arrMatch = RegExp(r'"steps"\s*:\s*\[').firstMatch(raw);
    if (arrMatch == null) return null;

    // Skip `completedSteps` complete objects to get to the in-progress one
    int i = arrMatch.end;
    int skipped = 0;
    final len = raw.length;

    while (i < len && skipped < completedSteps) {
      while (i < len && raw[i] != '{') {
        if (raw[i] == ']') return null;
        i++;
      }
      if (i >= len) return null;
      // Walk this complete object
      int depth = 0;
      bool inStr = false, esc = false;
      while (i < len) {
        final ch = raw[i];
        if (esc) {
          esc = false;
        } else if (ch == '\\' && inStr) {
          esc = true;
        } else if (ch == '"') {
          inStr = !inStr;
        } else if (!inStr) {
          if (ch == '{') depth++;
          if (ch == '}') {
            depth--;
            if (depth == 0) {
              i++;
              break;
            }
          }
        }
        i++;
      }
      skipped++;
    }

    // Now i points into the partial (incomplete) step region.
    // Find the opening '{' of the next step.
    while (i < len && raw[i] != '{') {
      if (raw[i] == ']') return null;
      i++;
    }
    if (i >= len) return null;

    final fragment = raw
        .substring(i); // e.g. {"number":2, "title":"Foo", "description":"Bar...

    int? number;
    String title = '';
    String description = '';

    final numM = RegExp(r'"number"\s*:\s*(\d+)').firstMatch(fragment);
    if (numM != null) number = int.tryParse(numM.group(1)!);

    final titleM =
        RegExp(r'"title"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(fragment);
    if (titleM != null) title = titleM.group(1)!.replaceAll(r'\"', '"');

    // For description, grab whatever is after `"description":"` even if cut off
    final descStart = RegExp(r'"description"\s*:\s*"').firstMatch(fragment);
    if (descStart != null) {
      final after = fragment.substring(descStart.end);
      // Find the closing quote that isn't escaped
      final sb = StringBuffer();
      bool esc2 = false;
      for (final ch in after.runes) {
        final c = String.fromCharCode(ch);
        if (esc2) {
          sb.write(c);
          esc2 = false;
          continue;
        }
        if (c == '\\') {
          esc2 = true;
          continue;
        }
        if (c == '"') break; // closing quote
        sb.write(c);
      }
      description = sb.toString();
    }

    if (number == null && title.isEmpty && description.isEmpty) return null;

    return _PartialStep(
      number: number ?? (completedSteps + 1),
      title: title,
      description: description,
    );
  }

  Future<void> startVoiceRecording() async {
    final hasPerms = await _audio.hasPermission();
    if (!hasPerms) {
      state = state.copyWith(
          errorMessage:
              'Microphone permission denied. Please enable in Settings.');
      return;
    }
    await _audio.startRecording();
    state = state.copyWith(isRecording: true);
  }

  Future<String?> stopVoiceRecording() async {
    if (!state.isRecording) return null;
    final path = await _audio.stopRecording();
    if (!mounted) return null;
    state = state.copyWith(isRecording: false);
    return path;
  }

  void clearError() => state = state.copyWith(errorMessage: null);
  void clearCards() => state = state.copyWith(cards: [], lastResponse: null);
}

// ── Private helper ──────────────────────────────────────────────────────────
class _PartialStep {
  final int number;
  final String title;
  final String description;
  const _PartialStep({
    required this.number,
    required this.title,
    required this.description,
  });
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final cactus = ref.watch(cactusServiceProvider);
  final storage = ref.watch(chatStorageProvider);
  final audio = ref.watch(audioServiceProvider);
  final tts = ref.watch(ttsServiceProvider);
  final modelState = ref.read(modelProvider);

  return ChatNotifier(
    cactus,
    storage,
    audio,
    tts,
    modelState.activeModelId,
    () => ref.read(settingsProvider),
  );
});

// ── Sessions list ──────────────────────────────────────────────────────────
final sessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final storage = ref.watch(chatStorageProvider);
  return storage.getAllSessions();
});

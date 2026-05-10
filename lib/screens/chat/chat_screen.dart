import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cactus/cactus.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ai_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/model_provider.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final modelState = ref.watch(modelProvider);

    // Auto-scroll when new messages come in
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (next.messages.length != prev?.messages.length ||
          next.isStreaming != prev?.isStreaming) {
        _scrollToBottom();
      }
    });

    final activeModel = modelState.activeModel;
    final isModelReady = activeModel?.isReady == true || !isCactusAvailable;

    return Scaffold(
      appBar: _ChatAppBar(
        modelStatus: activeModel?.status,
        isModelReady: isModelReady,
        onNewChat: () => ref.read(chatProvider.notifier).newChat(),
        onHistory: () => Navigator.pushNamed(context, '/history'),
      ),
      body: Column(
        children: [
          // Model loading banner
          if (!isModelReady && activeModel?.status == ModelStatus.loading)
            _ModelLoadingBanner(),

          // Error snack
          if (chatState.errorMessage != null)
            _ErrorBanner(
              message: chatState.errorMessage!,
              onDismiss: () => ref.read(chatProvider.notifier).clearError(),
            ),

          // Messages
          Expanded(
            child: chatState.messages.isEmpty
                ? _WelcomeScreen()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (_, i) =>
                        MessageBubble(message: chatState.messages[i]),
                  ),
          ),

          // Input bar
          ChatInputBar(
            isStreaming: chatState.isStreaming,
            isRecording: chatState.isRecording,
            attachedImages: const [],
            onSend: (text, images) {
              ref.read(chatProvider.notifier).sendMessage(
                    text,
                    imagePaths: images.isEmpty ? null : images,
                  );
            },
            onStartRecording: () =>
                ref.read(chatProvider.notifier).startVoiceRecording(),
            onStopRecording: () =>
                ref.read(chatProvider.notifier).stopVoiceRecording(),
            onCancelRecording: () =>
                ref.read(audioServiceProvider).cancelRecording(),
          ),
        ],
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ModelStatus? modelStatus;
  final bool isModelReady;
  final VoidCallback onNewChat;
  final VoidCallback onHistory;

  const _ChatAppBar({
    required this.modelStatus,
    required this.isModelReady,
    required this.onNewChat,
    required this.onHistory,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Text(
            'FixGemma',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          _StatusDot(isReady: isModelReady, status: modelStatus),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_comment_rounded),
          onPressed: onNewChat,
          tooltip: 'New chat',
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded),
          onPressed: onHistory,
          tooltip: 'History',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isReady;
  final ModelStatus? status;

  const _StatusDot({required this.isReady, this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ModelStatus.loading => (AppTheme.amber400, 'Loading'),
      ModelStatus.ready   => (AppTheme.green400, 'Ready'),
      ModelStatus.error   => (AppTheme.red400, 'Error'),
      _                   => (!isCactusAvailable
          ? (AppTheme.amber400, 'Demo mode')
          : (AppTheme.slate400, 'No model')),
    };

    return Tooltip(
      message: label,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

// ── Welcome screen ─────────────────────────────────────────────────────────
class _WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Big welcome header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.amber500.withOpacity(0.15),
                  AppTheme.amber600.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.amber400.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.build_circle_rounded,
                    color: AppTheme.amber400, size: 40),
                const SizedBox(height: 14),
                Text(
                  'Hi! I\'m FixGemma 👋',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your on-device AI repair assistant. I can help you diagnose and fix appliances step by step.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.slate400,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'What can I help with?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Quick start prompts
          ..._prompts.map((p) => _QuickPrompt(
                icon: p.$1,
                text: p.$2,
                subtitle: p.$3,
              )),
        ],
      ),
    );
  }

  static const _prompts = [
    (Icons.local_laundry_service_rounded, 'My washing machine won\'t drain',
        'Get step-by-step fix guide'),
    (Icons.kitchen_rounded, 'Fridge not cooling properly',
        'Diagnose the root cause'),
    (Icons.camera_alt_rounded, 'Take a photo of the problem',
        'I\'ll analyze it for you'),
    (Icons.mic_rounded, 'Use voice to describe the issue',
        'Just tap the mic and speak'),
  ];
}

class _QuickPrompt extends StatelessWidget {
  final IconData icon;
  final String text;
  final String subtitle;

  const _QuickPrompt({
    required this.icon,
    required this.text,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.slate800,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // These are just UI hints, not tappable prompts in the input
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.slate700),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.amber500.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.amber400, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppTheme.slate100,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.slate600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Banners ────────────────────────────────────────────────────────────────
class _ModelLoadingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.amber500.withOpacity(0.1),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading AI model…',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.amber400),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.red500.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.red400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.red400),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            color: AppTheme.slate400,
          ),
        ],
      ),
    );
  }
}

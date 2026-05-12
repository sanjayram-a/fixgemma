import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/page_transitions.dart';
import '../../core/widgets/floating_orbs_background.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../providers/chat_provider.dart';
import '../../models/ai_model.dart';
import '../../providers/model_provider.dart';
import 'response_screen.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  final String modelId;
  final String promptText;
  final List<String> imagePaths;
  final String? audioPath;
  final bool skipModelLoad;

  const LoadingScreen({
    super.key,
    required this.modelId,
    required this.promptText,
    this.imagePaths = const [],
    this.audioPath,
    this.skipModelLoad = false,
  });

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  String _statusText = 'Initializing model…';
  bool _generationStarted = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!widget.skipModelLoad) {
      // Load the model
      setState(() => _statusText = 'Loading AI model…');
      await ref.read(modelProvider.notifier).loadModel(widget.modelId);

      final modelState = ref.read(modelProvider);
      final aiModel = modelState.models.firstWhere(
        (m) => m.id == widget.modelId,
        orElse: () => throw Exception('Model not found'),
      );

      if (aiModel.status == ModelStatus.error) {
        if (mounted) {
          setState(() => _statusText = 'Error loading model: ${aiModel.errorMessage}');
        }
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
        return;
      }
    }

    // Start generation
    if (!mounted) return;
    setState(() {
      _statusText = 'Generating repair guide…';
      _generationStarted = true;
    });

    // Trigger new chat session and send the message
    final chat = ref.read(chatProvider.notifier);
    await chat.newChat();
    if (!mounted) return;

    // Send in background, navigate as soon as first card appears
    _sendAndWatch();
  }

  void _sendAndWatch() {
    ref.read(chatProvider.notifier).sendMessage(
      widget.promptText,
      imagePaths: widget.imagePaths.isNotEmpty ? widget.imagePaths : null,
      audioPath: widget.audioPath,
    );

    // Watch for first card to appear then navigate
    _waitForFirstCard();
  }

  Future<void> _waitForFirstCard() async {
    // Poll until cards appear or a timeout
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      final state = ref.read(chatProvider);
      if (state.cards.isNotEmpty) {
        // Navigate to response screen
        Navigator.pushReplacement(
          context,
          slideUpRoute(const ResponseScreen()),
        );
        return;
      }

      if (!state.isStreaming && state.cards.isEmpty && i > 4) {
        // Model returned empty — navigate anyway
        Navigator.pushReplacement(
          context,
          slideUpRoute(const ResponseScreen()),
        );
        return;
      }
    }

    // Timeout fallback
    if (mounted) {
      Navigator.pushReplacement(
        context,
        slideUpRoute(const ResponseScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated dots
                  LoadingAnimationWidget.fourRotatingDots(
                    color: AppTheme.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 40),

                  // Status card
                  FrostedGlassCard(
                    borderRadius: 20,
                    blur: 16,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FixGemma',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            _statusText,
                            key: ValueKey(_statusText),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.onSurfaceSub),
                          ),
                        ),
                        if (_generationStarted) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  AppTheme.tertiary.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

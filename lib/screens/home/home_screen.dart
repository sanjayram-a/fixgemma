import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/hf_models.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/model_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';
import 'widgets/model_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelProvider);
    final hasReadyModel =
        modelState.models.any((m) => m.isReady || m.isDownloaded);
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Scale card height so it never blows out on small screens
    final cardHeight = (screenHeight * 0.52).clamp(320.0, 480.0);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top bar ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.amber500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.build_circle_rounded,
                          color: AppTheme.amber400, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FixGemma',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text('Your repair assistant',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
            ),

            // ── Hero message ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasReadyModel
                          ? 'Ready to fix!'
                          : 'Download to get started',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasReadyModel
                          ? 'Your AI repair assistant is ready. Start a chat below.'
                          : 'Choose a model below. The AI runs fully on your phone — no internet needed for chats.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.slate400,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section label ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Text(
                  'AI Models',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppTheme.slate400),
                ),
              ),
            ),

            // ── Model cards (horizontal scroll) ──────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: cardHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 24, right: 8),
                  itemCount: kAvailableModels.length,
                  itemBuilder: (context, i) {
                    final def = kAvailableModels[i];
                    final model = modelState.models.firstWhere(
                      (m) => m.id == def.id,
                      orElse: () => throw StateError('Model not found'),
                    );
                    final progress = modelState.downloadProgress[def.id];
                    return ModelCard(def: def, model: model, progress: progress);
                  },
                ),
              ),
            ),

            // ── Bottom buttons (fill remaining space so they're at the bottom
            //    when content is short, but scroll naturally when tall) ────────
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!hasReadyModel) ...[
                      _InfoBanner(
                        icon: Icons.info_outline_rounded,
                        text:
                            'Download a model first to start chatting. You only need to do this once.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      onPressed: hasReadyModel
                          ? () async {
                              await ref.read(chatProvider.notifier).newChat();
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ChatScreen()),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: const Text('New Chat'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (hasReadyModel) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/history'),
                        icon: const Icon(Icons.history_rounded, size: 20),
                        label: const Text('Chat History'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.slate800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate700),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.slate400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.slate400, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

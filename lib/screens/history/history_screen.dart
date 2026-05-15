import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/page_transitions.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../models/chat_session.dart';
import '../../providers/chat_provider.dart';
import '../response/response_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _pendingDelete = {};

  @override
  void initState() {
    super.initState();
    // Refresh list every time this widget is inserted (tab switch)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(sessionsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'History',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                IconButton(
                  onPressed: () => ref.invalidate(sessionsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppTheme.primary,
                  iconSize: 22,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Past repair sessions',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.onSurfaceSub),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: sessionsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppTheme.red400)),
                ),
                data: (sessions) {
                  // Exclude sessions currently being deleted
                  final visible = sessions
                      .where((s) => !_pendingDelete.contains(s.id))
                      .toList();

                  if (visible.isEmpty) return _EmptyState();

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final s = visible[i];
                      return Dismissible(
                        key: ValueKey(s.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.red400.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: AppTheme.red400),
                        ),
                        onDismissed: (_) {
                          // Mark as pending so it stays gone even before async delete
                          setState(() => _pendingDelete.add(s.id));
                          _deleteSession(s);
                        },
                        child: _SessionCard(
                          session: s,
                          onTap: () => _openSession(s),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _openSession(ChatSession session) async {
    await ref.read(chatProvider.notifier).loadSession(session);
    if (!mounted) return;
    Navigator.push(context, slideUpRoute(const ResponseScreen()));
  }

  Future<void> _deleteSession(ChatSession session) async {
    final storage = ref.read(chatStorageProvider);
    await storage.deleteSession(session.id);
    ref.invalidate(sessionsProvider);
    // Clean up the pending-delete guard now that deletion is confirmed
    if (mounted) setState(() => _pendingDelete.remove(session.id));
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 56, color: AppTheme.tertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No past sessions yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.onSurfaceSub)),
          const SizedBox(height: 6),
          Text('Start a repair to see it here',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.onSurfaceSub)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final preview = session.messages.isNotEmpty
        ? () {
            final first = session.messages.firstWhere((m) => m.role == 'user',
                orElse: () => session.messages.first);
            final text = first.content.trim();
            if (text.isNotEmpty) return text;
            if (first.audioPath != null) return 'Voice input';
            if (first.imagePaths != null && first.imagePaths!.isNotEmpty) {
              return 'Image input';
            }
            return 'Empty session';
          }()
        : 'Empty session';

    final date = DateFormat('MMM d · h:mm a').format(session.updatedAt);

    return FrostedGlassCard(
      borderRadius: 20,
      blur: 12,
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.build_rounded,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.length > 60
                      ? '${preview.substring(0, 60)}…'
                      : preview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 11, color: AppTheme.onSurfaceSub),
                    const SizedBox(width: 4),
                    Text(date,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.onSurfaceSub)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceSub, size: 20),
        ],
      ),
    );
  }
}

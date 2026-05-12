import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/page_transitions.dart';
import '../../core/widgets/floating_orbs_background.dart';
import '../settings/settings_screen.dart';
import '../history/history_screen.dart';
import 'widgets/model_card.dart';
import '../../providers/model_provider.dart';
import '../../core/constants/hf_models.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          IndexedStack(
            index: _navIndex,
            children: [
              _HomeTab(onNavChanged: _setNav),
              const HistoryScreen(),
            ],
          ),
          // Bottom nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(
              currentIndex: _navIndex,
              onTap: _setNav,
            ),
          ),
        ],
      ),
    );
  }

  void _setNav(int i) => setState(() => _navIndex = i);
}

// ── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  final ValueChanged<int> onNavChanged;
  const _HomeTab({required this.onNavChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            // ── Top bar: fixgemma (left) | ⚙️ (right) ────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'fixgemma',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    slideUpRoute(const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings_rounded),
                  color: AppTheme.primary,
                  iconSize: 26,
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Choose your repair model',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceSub,
                  ),
            ),
            // ── Model Cards ───────────────────────────────────────────────
            // Flexible + FractionallySizedBox keeps cards slightly shorter
            // than the full available height — user-requested size reduction.
            Flexible(
              child: FractionallySizedBox(
                heightFactor: 0.88,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    // Model 1 — Full size
                    Expanded(
                      child: ModelCard(model: kAvailableModels[0]),
                    ),
                    const SizedBox(height: 16),
                    // Model 2 — Lite
                    Expanded(
                      child: ModelCard(model: kAvailableModels[1]),
                    ),
                    // Space for bottom nav
                    const SizedBox(height: 70),
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

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.bgColor.withValues(alpha: 0),
            AppTheme.bgColor.withValues(alpha: 0.92),
            AppTheme.bgColor,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.history_rounded,
            label: 'History',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.onSurfaceSub;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: color,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

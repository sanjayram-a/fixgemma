import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Three slowly floating blurred orbs as background decoration.
class FloatingOrbsBackground extends StatefulWidget {
  const FloatingOrbsBackground({super.key});

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground>
    with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _c2 = AnimationController(vsync: this, duration: const Duration(seconds: 11))
      ..repeat(reverse: true);
    _c3 = AnimationController(vsync: this, duration: const Duration(seconds: 14))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_c1, _c2, _c3]),
      builder: (_, __) {
        return Stack(
          children: [
            // Orb 1 — primary
            _Orb(
              color: AppTheme.primary,
              radius: 110,
              x: _lerp(0.05, 0.35, _c1.value) * size.width,
              y: _lerp(0.08, 0.3, _c1.value) * size.height,
            ),
            // Orb 2 — secondary
            _Orb(
              color: AppTheme.secondary,
              radius: 90,
              x: _lerp(0.55, 0.85, _c2.value) * size.width,
              y: _lerp(0.5, 0.75, _c2.value) * size.height,
            ),
            // Orb 3 — tertiary
            _Orb(
              color: AppTheme.tertiary,
              radius: 120,
              x: _lerp(0.2, 0.7, _c3.value) * size.width,
              y: _lerp(0.55, 0.9, _c3.value) * size.height,
            ),
          ],
        );
      },
    );
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _Orb extends StatelessWidget {
  final Color color;
  final double radius;
  final double x;
  final double y;

  const _Orb({
    required this.color,
    required this.radius,
    required this.x,
    required this.y,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - radius,
      top: y - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

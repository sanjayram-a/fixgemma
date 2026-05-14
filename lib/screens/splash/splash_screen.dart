import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/floating_orbs_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    // Navigate after short delay
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          // Centered logo text
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon orb
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.secondary,
                          AppTheme.primary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.build_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'FixGemma',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Appliance Repair Assistant',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.onSurfaceSub,
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

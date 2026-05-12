import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/page_transitions.dart';
import '../../core/widgets/floating_orbs_background.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../providers/chat_provider.dart';
import '../../models/ai_model.dart';
import '../../providers/model_provider.dart';
import '../response/loading_screen.dart';

class VoicePromptScreen extends ConsumerStatefulWidget {
  final String modelId;

  const VoicePromptScreen({super.key, required this.modelId});

  @override
  ConsumerState<VoicePromptScreen> createState() => _VoicePromptScreenState();
}

class _VoicePromptScreenState extends ConsumerState<VoicePromptScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  List<File> _images = [];
  String? _recordedPath;
  bool _isPlaying = false;

  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final chat = ref.read(chatProvider.notifier);
    final state = ref.read(chatProvider);

    if (state.isRecording) {
      final path = await chat.stopVoiceRecording();
      if (!mounted) return;
      setState(() => _recordedPath = path);
    } else {
      setState(() => _recordedPath = null);
      await chat.startVoiceRecording();
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(
          () => _images = [..._images, ...picked.map((x) => File(x.path))]);
    }
  }

  Future<void> _startFix() async {
    if (_recordedPath == null && _images.isEmpty) return;

    final modelState = ref.read(modelProvider);
    final aiModel = modelState.models.firstWhere(
      (m) => m.id == widget.modelId,
      orElse: () => throw Exception('Model not found'),
    );

    final skipLoad = aiModel.status == ModelStatus.ready;
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      slideUpRoute(LoadingScreen(
        modelId: widget.modelId,
        promptText: '',
        imagePaths: _images.map((f) => f.path).toList(),
        audioPath: _recordedPath,
        skipModelLoad: skipLoad,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isRecording = chatState.isRecording;
    final hasRecording = _recordedPath != null;

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: AppTheme.onSurface,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (hasRecording)
                        FrostedGlassCard(
                          borderRadius: 10,
                          blur: 10,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppTheme.green400, size: 16),
                              const SizedBox(width: 6),
                              Text('Recorded',
                                  style: TextStyle(
                                      color: AppTheme.green400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Status label
                Text(
                  isRecording
                      ? 'Recording…'
                      : hasRecording
                          ? 'Recording ready'
                          : 'Tap to start',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isRecording
                            ? AppTheme.red400
                            : AppTheme.onSurfaceSub,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 32),

                // ── Big mic button ──────────────────────────────────────
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated outer rings when recording
                      if (isRecording) ...[
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 140 + 20 * _pulseCtrl.value,
                            height: 140 + 20 * _pulseCtrl.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.red400
                                  .withValues(alpha: 0.08 + 0.08 * _pulseCtrl.value),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Container(
                            width: 120 + 12 * _pulseCtrl.value,
                            height: 120 + 12 * _pulseCtrl.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.red400
                                  .withValues(alpha: 0.12 + 0.08 * _pulseCtrl.value),
                            ),
                          ),
                        ),
                      ],

                      // Core button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isRecording
                                ? [AppTheme.red400, const Color(0xFFB71C1C)]
                                : [AppTheme.secondary, AppTheme.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isRecording
                                      ? AppTheme.red400
                                      : AppTheme.primary)
                                  .withValues(alpha: 0.45),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Audio wave visualiser (decorative while recording)
                if (isRecording) _WaveVisualiser(controller: _waveCtrl),

                const Spacer(),

                // ── Attached images ─────────────────────────────────────
                if (_images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _ImageThumb(
                          file: _images[i],
                          onRemove: () =>
                              setState(() => _images.removeAt(i)),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Bottom action row ─────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      22, 0, 22, MediaQuery.of(context).padding.bottom + 16),
                  child: Row(
                    children: [
                      // + Image button
                      _GlassIconBtn(
                        icon: Icons.add_photo_alternate_rounded,
                        onTap: _pickImage,
                        tooltip: 'Add image',
                      ),
                      const Spacer(),
                      // FIX button (enabled only when recording exists)
                      AnimatedOpacity(
                        opacity: hasRecording ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: hasRecording ? _startFix : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 36, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                            shadowColor:
                                AppTheme.primary.withValues(alpha: 0.35),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('FIX',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Audio wave visualiser (decorative) ──────────────────────────────────────
class _WaveVisualiser extends StatelessWidget {
  final AnimationController controller;
  const _WaveVisualiser({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(controller.value),
        size: const Size(200, 48),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.red400.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final mid = size.height / 2;
    const bars = 24;

    for (int i = 0; i < bars; i++) {
      final x = (size.width / bars) * (i + 0.5);
      final amp = (sin((i / bars + t) * 2 * pi) * 0.5 + 0.5) * (mid * 0.85);
      canvas.drawLine(
        Offset(x, mid - amp),
        Offset(x, mid + amp),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────
class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _GlassIconBtn(
      {required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FrostedGlassCard(
        width: 52,
        height: 52,
        borderRadius: 14,
        blur: 12,
        padding: EdgeInsets.zero,
        child: Tooltip(
          message: tooltip ?? '',
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _ImageThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child:
              Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: AppTheme.red400, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

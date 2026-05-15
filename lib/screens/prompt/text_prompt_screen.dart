import 'dart:io';
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
import 'voice_prompt_screen.dart';

class TextPromptScreen extends ConsumerStatefulWidget {
  final String modelId;

  const TextPromptScreen({super.key, required this.modelId});

  @override
  ConsumerState<TextPromptScreen> createState() => _TextPromptScreenState();
}

class _TextPromptScreenState extends ConsumerState<TextPromptScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  List<File> _images = [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || source == null) return;

    if (source == ImageSource.camera) {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _images = [..._images, File(picked.path)]);
      }
      return;
    }

    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _images = [..._images, ...picked.map((x) => File(x.path))];
      });
    }
  }

  Future<void> _startFix() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _images.isEmpty) {
      _focus.requestFocus();
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);

    // Ensure model loaded
    final modelState = ref.read(modelProvider);
    final aiModel = modelState.models.firstWhere(
      (m) => m.id == widget.modelId,
      orElse: () => throw Exception('Model not found'),
    );

    if (aiModel.status != ModelStatus.ready) {
      // Load model first — navigate to loading screen
      Navigator.pushReplacement(
        context,
        slideUpRoute(LoadingScreen(
          modelId: widget.modelId,
          promptText: text,
          imagePaths: _images.map((f) => f.path).toList(),
        )),
      );
      return;
    }

    // Model already ready — go directly to loading screen to trigger gen
    Navigator.pushReplacement(
      context,
      slideUpRoute(LoadingScreen(
        modelId: widget.modelId,
        promptText: text,
        imagePaths: _images.map((f) => f.path).toList(),
        skipModelLoad: true,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                        color: AppTheme.onSurface,
                      ),
                      const Spacer(),
                      // Voice mode button
                      _GlassIconBtn(
                        icon: Icons.mic_rounded,
                        tooltip: 'Switch to voice',
                        onTap: () {
                          Navigator.push(
                            context,
                            slideHorizontalRoute(
                              VoicePromptScreen(modelId: widget.modelId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Prompt title ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What are you\ngoing to fix?',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Describe the issue or attach a photo',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.onSurfaceSub,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Text input ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: FrostedGlassCard(
                      borderRadius: 22,
                      blur: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppTheme.onSurface),
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. My washing machine makes a loud noise during the spin cycle…',
                                hintStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppTheme.onSurfaceSub),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),

                          // Attached images row
                          if (_images.isNotEmpty) ...[
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 72,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _images.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) => _ImageThumb(
                                  file: _images[i],
                                  onRemove: () =>
                                      setState(() => _images.removeAt(i)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Bottom action row ────────────────────────────────────
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
                        size: 52,
                      ),
                      const Spacer(),
                      // FIX button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _sending ? null : _startFix,
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
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('FIX',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded,
                                        size: 20),
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

// ── Glass icon button ────────────────────────────────────────────────────────
class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  const _GlassIconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: FrostedGlassCard(
          width: size,
          height: size,
          borderRadius: 14,
          blur: 12,
          padding: EdgeInsets.zero,
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
      ),
    );
  }
}

// ── Image thumbnail ──────────────────────────────────────────────────────────
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
          child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
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

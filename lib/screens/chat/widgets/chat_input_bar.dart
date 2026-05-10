import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final bool isStreaming;
  final bool isRecording;
  final List<String> attachedImages;
  final void Function(String text, List<String> images) onSend;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  const ChatInputBar({
    super.key,
    required this.isStreaming,
    required this.isRecording,
    required this.attachedImages,
    required this.onSend,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final List<String> _images = [];
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _images.addAll(widget.attachedImages);
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.trim().isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    if (widget.isStreaming) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    widget.onSend(text, List.from(_images));
    _controller.clear();
    setState(() => _images.clear());
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file != null) {
      setState(() => _images.add(file.path));
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.slate900,
        border: Border(top: BorderSide(color: AppTheme.slate700)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image previews
              if (_images.isNotEmpty) _ImagePreviews(images: _images, onRemove: (i) => setState(() => _images.removeAt(i))),

              // Recording indicator with stop + cancel
              if (widget.isRecording)
                _RecordingBar(
                  onCancel: widget.onCancelRecording,
                  onStop: widget.onStopRecording,
                ),

              if (!widget.isRecording)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Camera button
                    _InputIconButton(
                      icon: Icons.add_photo_alternate_rounded,
                      onTap: _showImagePicker,
                      tooltip: 'Add image',
                    ),
                    const SizedBox(width: 8),

                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !widget.isStreaming,
                        decoration: InputDecoration(
                          hintText: widget.isStreaming
                              ? 'Generating…'
                              : 'Ask about your appliance…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mic / Send button
                    if (!_hasText && _images.isEmpty)
                      _MicButton(onTap: widget.onStartRecording)
                    else
                      _SendButton(
                        enabled: !widget.isStreaming,
                        onTap: _send,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _InputIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.slate800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.slate700),
          ),
          child: Icon(icon, color: AppTheme.slate400, size: 22),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MicButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.slate800,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.slate700),
        ),
        child: const Icon(Icons.mic_rounded, color: AppTheme.slate400, size: 22),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.amber400 : AppTheme.slate700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send_rounded,
          color: enabled ? AppTheme.slate900 : AppTheme.slate600,
          size: 20,
        ),
      ),
    );
  }
}

class _RecordingBar extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onStop;
  const _RecordingBar({required this.onCancel, required this.onStop});

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.red500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.red500.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.red400.withValues(alpha: 0.4 + _ctrl.value * 0.6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Recording… Tap send when done',
              style: TextStyle(
                  color: AppTheme.red400,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
          // Cancel button
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.slate400, size: 20),
            onPressed: widget.onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Cancel',
          ),
          const SizedBox(width: 8),
          // Stop & Send button
          GestureDetector(
            onTap: widget.onStop,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.amber400,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.slate900, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviews extends StatelessWidget {
  final List<String> images;
  final void Function(int index) onRemove;

  const _ImagePreviews({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (_, i) {
          return Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(File(images[i])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.slate900,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.slate100),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


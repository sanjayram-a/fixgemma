import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final AppMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Images if any
                if (message.imagePaths != null &&
                    message.imagePaths!.isNotEmpty)
                  _ImageAttachments(paths: message.imagePaths!),

                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.80,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.amber500 : AppTheme.slate800,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: AppTheme.slate700),
                  ),
                  child: isUser
                      ? _UserContent(message: message)
                      : _AssistantContent(message: message),
                ),

                // Timestamp
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser
            ? AppTheme.amber500.withValues(alpha: 0.2)
            : AppTheme.slate700,
        border: Border.all(
          color: isUser
              ? AppTheme.amber400.withValues(alpha: 0.3)
              : AppTheme.slate600,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.build_circle_rounded,
        size: 18,
        color: isUser ? AppTheme.amber400 : AppTheme.slate400,
      ),
    );
  }
}

class _UserContent extends StatelessWidget {
  final AppMessage message;
  const _UserContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.audioPath != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_rounded,
                    size: 16, color: AppTheme.slate900),
                const SizedBox(width: 4),
                Text(
                  'Voice message',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.slate900),
                ),
              ],
            ),
          if (message.content.isNotEmpty)
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate900,
                    fontWeight: FontWeight.w500,
                  ),
            ),
        ],
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final AppMessage message;
  const _AssistantContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: message.isStreaming && message.content.isEmpty
          ? _TypingDots()
          : MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.slate100,
                      height: 1.55,
                    ),
                h1: Theme.of(context).textTheme.headlineSmall,
                h2: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 16,
                    ),
                h3: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                code: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppTheme.amber400,
                      backgroundColor: AppTheme.slate900,
                    ),
                blockquotePadding: const EdgeInsets.only(left: 12),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppTheme.amber400, width: 3),
                  ),
                ),
              ),
            ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final phase = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
              final y = -6 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.slate400.withValues(alpha: 0.7),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImageAttachments extends StatelessWidget {
  final List<String> paths;
  const _ImageAttachments({required this.paths});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: paths.map((p) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(p),
              width: 120,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 90,
                color: AppTheme.slate700,
                child: const Icon(Icons.image_rounded, color: AppTheme.slate400),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

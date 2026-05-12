import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/hf_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/page_transitions.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../models/ai_model.dart';
import '../../../models/download_state.dart';
import '../../../providers/model_provider.dart';
import '../../prompt/text_prompt_screen.dart';

class ModelCard extends ConsumerWidget {
  final HFModelDef model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelProvider);
    final aiModel = modelState.models.firstWhere(
      (m) => m.id == model.id,
      orElse: () => AIModel(id: model.id),
    );
    final progress = modelState.downloadProgress[model.id];
    final isReady = aiModel.status == ModelStatus.ready;

    return GestureDetector(
      onTap: isReady ? () => _navigateToPrompt(context, ref) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.74),
                  Colors.white.withValues(alpha: 0.56),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _borderColor(aiModel.status),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            // LayoutBuilder lets us size content relative to the real height
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxHeight < 230;
              return Padding(
                padding: EdgeInsets.all(compact ? 14 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // ── Header ──────────────────────────────────
                    _Header(model: model, aiModel: aiModel, compact: compact),

                    SizedBox(height: compact ? 8 : 10),

                    // ── Description ──────────────────────────────
                    Text(
                      model.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceSub,
                            height: 1.4,
                          ),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: compact ? 6 : 8),

                    // ── Capabilities ─────────────────────────────
                    _CapRow(capabilities: model.capabilities),

                    const Spacer(),

                    // ── Action ────────────────────────────────────
                    _buildAction(context, ref, aiModel, progress, compact),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _navigateToPrompt(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      slideUpRoute(TextPromptScreen(modelId: model.id)),
    );
  }

  Widget _buildAction(BuildContext context, WidgetRef ref, AIModel aiModel,
      DownloadProgress? progress, bool compact) {
    switch (aiModel.status) {
      case ModelStatus.notDownloaded:
        return _PrimaryBtn(
          icon: Icons.download_rounded,
          label: 'Download  •  ${model.sizeLabel}',
          onTap: () => ref.read(modelProvider.notifier).startDownload(model.id),
          compact: compact,
        );

      case ModelStatus.downloading:
        return _ProgressWidget(progress: progress, compact: compact);

      case ModelStatus.paused:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressWidget(progress: progress, compact: compact),
            SizedBox(height: compact ? 6 : 8),
            _PrimaryBtn(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              onTap: () =>
                  ref.read(modelProvider.notifier).startDownload(model.id),
              compact: compact,
            ),
          ],
        );

      case ModelStatus.downloaded:
        return _PrimaryBtn(
          icon: Icons.play_circle_rounded,
          label: 'Load Model',
          onTap: () => ref.read(modelProvider.notifier).loadModel(model.id),
          compact: compact,
        );

      case ModelStatus.loading:
        return _PrimaryBtn(
          icon: null,
          label: 'Loading model…',
          onTap: null,
          loading: true,
          compact: compact,
        );

      case ModelStatus.ready:
        return _PrimaryBtn(
          icon: Icons.arrow_forward_rounded,
          label: 'Start Repair',
          onTap: () => _navigateToPrompt(context, ref),
          compact: compact,
        );

      case ModelStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  aiModel.errorMessage ?? 'Error',
                  style: TextStyle(
                      color: AppTheme.red400,
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            _PrimaryBtn(
              icon: Icons.refresh_rounded,
              label: aiModel.localDirPath != null ? 'Retry Load' : 'Retry',
              onTap: () {
                final n = ref.read(modelProvider.notifier);
                if (aiModel.localDirPath != null) {
                  n.loadModel(model.id);
                } else {
                  n.startDownload(model.id);
                }
              },
              compact: compact,
            ),
          ],
        );
    }
  }

  Color _borderColor(ModelStatus status) {
    return switch (status) {
      ModelStatus.ready => AppTheme.secondary.withValues(alpha: 0.6),
      ModelStatus.downloaded => AppTheme.green400.withValues(alpha: 0.4),
      ModelStatus.downloading => AppTheme.tertiary,
      ModelStatus.error => AppTheme.red400.withValues(alpha: 0.3),
      _ => AppTheme.frostedBorder,
    };
  }
}

// ── Header row ───────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final HFModelDef model;
  final AIModel aiModel;
  final bool compact;

  const _Header({
    required this.model,
    required this.aiModel,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 40.0 : 48.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon orb
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.secondary, AppTheme.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(model.icon, color: Colors.white,
              size: compact ? 20 : 24),
        ),
        const SizedBox(width: 12),
        // Name + meta — Flexible prevents right overflow
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.storage_rounded,
                      size: 11, color: AppTheme.onSurfaceSub),
                  const SizedBox(width: 3),
                  Text(
                    model.sizeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.onSurfaceSub),
                  ),
                  const SizedBox(width: 6),
                  _QuantChip(label: model.quantization),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _StatusBadge(status: aiModel.status),
      ],
    );
  }
}

// ── Capability chips row ─────────────────────────────────────────────────────
class _CapRow extends StatelessWidget {
  final List<String> capabilities;
  const _CapRow({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: capabilities.map((c) => _CapChip(label: c)).toList(),
    );
  }
}

// ── Primary action button ─────────────────────────────────────────────────────
class _PrimaryBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool compact;

  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 38 : 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onTap == null ? AppTheme.tertiary : AppTheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              vertical: compact ? 0 : 4, horizontal: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : icon != null
                ? Icon(icon, size: 18)
                : const SizedBox.shrink(),
        label: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Download progress ─────────────────────────────────────────────────────────
class _ProgressWidget extends StatelessWidget {
  final DownloadProgress? progress;
  final bool compact;
  const _ProgressWidget({this.progress, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final isExtracting = p?.status == DownloadStatus.extracting;
    final pct = isExtracting
        ? (p?.extractProgress ?? 0.0)
        : (p?.overallProgress ?? 0.0);
    final pctStr = '${(pct * 100).toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExtracting ? 'Extracting…' : 'Downloading…',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.onSurfaceSub),
            ),
            Text(pctStr,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v > 0 ? v : null,
              minHeight: 6,
              backgroundColor: AppTheme.tertiary.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(
                  isExtracting ? AppTheme.green400 : AppTheme.primary),
            ),
          ),
        ),
        if (!compact && p != null && p.totalBytes > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${(p.bytesReceived / 1e9).toStringAsFixed(1)} / '
                '${(p.totalBytes / 1e9).toStringAsFixed(1)} GB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.onSurfaceSub),
              ),
              if (p.speedBps > 0) ...[
                const Spacer(),
                Text(
                  StorageUtils.formatSpeed(p.speedBps),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.onSurfaceSub),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final ModelStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == ModelStatus.notDownloaded ||
        status == ModelStatus.downloading) return const SizedBox.shrink();

    final (String label, Color color) = switch (status) {
      ModelStatus.ready => ('● Ready', AppTheme.secondary),
      ModelStatus.downloaded => ('✓ Done', AppTheme.green400),
      ModelStatus.loading => ('Loading…', AppTheme.tertiary),
      ModelStatus.error => ('Error', AppTheme.red400),
      _ => ('', AppTheme.onSurfaceSub),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _QuantChip extends StatelessWidget {
  final String label;
  const _QuantChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary)),
    );
  }
}

class _CapChip extends StatelessWidget {
  final String label;
  const _CapChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (label) {
      'vision' => (Icons.remove_red_eye_rounded, AppTheme.secondary),
      'audio' => (Icons.mic_rounded, const Color(0xFF7C5CBF)),
      _ => (Icons.chat_rounded, AppTheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

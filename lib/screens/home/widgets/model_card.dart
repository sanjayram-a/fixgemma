import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/hf_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../models/ai_model.dart';
import '../../../models/download_state.dart';
import '../../../providers/model_provider.dart';

class ModelCard extends ConsumerWidget {
  final HFModelDef def;
  final AIModel model;
  final DownloadProgress? progress;

  const ModelCard({
    super.key,
    required this.def,
    required this.model,
    this.progress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComingSoon = def.isComingSoon;

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppTheme.slate800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _borderColor(model.status),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isComingSoon
                        ? AppTheme.slate700
                        : AppTheme.amber500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    def.icon,
                    color: isComingSoon ? AppTheme.slate400 : AppTheme.amber400,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        def.quantization,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.amber400,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isComingSoon)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.slate700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Soon',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              def.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate400,
                    height: 1.5,
                  ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // Capability chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  def.capabilities.map((c) => _CapChip(label: c)).toList(),
            ),

            const SizedBox(height: 20),

            // Size
            Row(
              children: [
                Icon(Icons.storage_rounded, size: 14, color: AppTheme.slate400),
                const SizedBox(width: 4),
                Text(
                  def.sizeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const Spacer(),

            // Action area
            if (!isComingSoon) _buildActionArea(context, ref),
            if (isComingSoon)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('Coming Soon'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shows a confirmation dialog then deletes the model.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded,
                color: AppTheme.red400, size: 22),
            const SizedBox(width: 10),
            const Text('Delete Model?'),
          ],
        ),
        content: Text(
          'This will permanently remove "${def.displayName}" and all its files '
          'from your device. You can re-download it later.',
          style: TextStyle(color: AppTheme.slate400, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.red500,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(modelProvider.notifier).deleteModel(def.id);
    }
  }

  Widget _buildActionArea(BuildContext context, WidgetRef ref) {
    switch (model.status) {
      case ModelStatus.notDownloaded:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(modelProvider.notifier).startDownload(def.id),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download Model'),
          ),
        );

      case ModelStatus.downloading:
        return _DownloadingWidget(progress: progress);

      case ModelStatus.paused:
        return Column(
          children: [
            _DownloadingWidget(progress: progress),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(modelProvider.notifier).startDownload(def.id),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume'),
              ),
            ),
          ],
        );

      case ModelStatus.downloaded:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.green500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.green500.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppTheme.green400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Downloaded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.green400,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    ref.read(modelProvider.notifier).loadModel(def.id),
                icon: const Icon(Icons.play_circle_rounded),
                label: const Text('Load Model'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppTheme.red400, size: 18),
                label: Text('Delete Model',
                    style: TextStyle(color: AppTheme.red400)),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: AppTheme.red500.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        );

      case ModelStatus.loading:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: const Text('Loading…'),
          ),
        );

      case ModelStatus.ready:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.amber500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.amber400.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flash_on_rounded,
                      color: AppTheme.amber400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Ready to use',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: AppTheme.amber400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppTheme.red400, size: 18),
                label: Text('Delete Model',
                    style: TextStyle(color: AppTheme.red400)),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: AppTheme.red500.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        );

      case ModelStatus.error:
        final canRetryLoad = model.localDirPath != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.red500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppTheme.red400, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.errorMessage ?? 'Download failed',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.red400),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final notifier = ref.read(modelProvider.notifier);
                  if (canRetryLoad) {
                    notifier.loadModel(def.id);
                  } else {
                    notifier.startDownload(def.id);
                  }
                },
                icon: Icon(canRetryLoad
                    ? Icons.play_circle_outline_rounded
                    : Icons.refresh_rounded),
                label: Text(canRetryLoad ? 'Try Loading Again' : 'Retry'),
              ),
            ),
            if (canRetryLoad) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(modelProvider.notifier).startDownload(def.id),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Again'),
                ),
              ),
            ],
          ],
        );
    }
  }

  static Color _borderColor(ModelStatus status) {
    switch (status) {
      case ModelStatus.ready:
        return AppTheme.amber400.withValues(alpha: 0.4);
      case ModelStatus.downloaded:
        return AppTheme.green500.withValues(alpha: 0.3);
      case ModelStatus.downloading:
        return AppTheme.amber500.withValues(alpha: 0.3);
      case ModelStatus.error:
        return AppTheme.red500.withValues(alpha: 0.3);
      default:
        return AppTheme.slate700;
    }
  }
}

// ── Downloading progress widget ────────────────────────────────────────────
class _DownloadingWidget extends StatelessWidget {
  final DownloadProgress? progress;

  const _DownloadingWidget({this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final isExtracting = p?.status == DownloadStatus.extracting;

    if (isExtracting) return _buildExtracting(context, p!);
    return _buildDownloading(context, p);
  }

  Widget _buildDownloading(BuildContext context, DownloadProgress? p) {
    final pct = p?.overallProgress ?? 0.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    String sizeLabel = '';
    if (p != null && p.totalBytes > 0) {
      final rxGb = p.bytesReceived / (1024 * 1024 * 1024);
      final totalGb = p.totalBytes / (1024 * 1024 * 1024);
      sizeLabel =
          '${rxGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading AI model',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.slate400),
            ),
            Text(
              pctLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.amber400,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Animated progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value > 0 ? value : null,
              minHeight: 8,
              backgroundColor: AppTheme.slate700,
              valueColor: const AlwaysStoppedAnimation(AppTheme.amber400),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Size line
        if (sizeLabel.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.storage_rounded,
                  size: 12, color: AppTheme.slate400),
              const SizedBox(width: 4),
              Text(sizeLabel, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),

        const SizedBox(height: 4),

        // Speed + ETA line
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (p != null && p.speedBps > 0)
              Row(
                children: [
                  const Icon(Icons.speed_rounded,
                      size: 12, color: AppTheme.slate400),
                  const SizedBox(width: 4),
                  Text(
                    StorageUtils.formatSpeed(p.speedBps),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            if (p != null && p.eta != null)
              Text(
                '~${StorageUtils.formatEta(p.eta!)} left',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.slate400),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtracting(BuildContext context, DownloadProgress p) {
    final pct = p.extractProgress;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';
    final partLabel =
        p.totalFiles > 1 ? ' (${p.filesCompleted + 1} of ${p.totalFiles})' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extracting$partLabel…',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.slate400),
            ),
            Text(
              pctLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.amber400,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Extraction bar — green tint to visually differ from download
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value > 0 ? value : null,
              minHeight: 8,
              backgroundColor: AppTheme.slate700,
              valueColor: AlwaysStoppedAnimation(AppTheme.green400),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(Icons.folder_zip_rounded,
                size: 12, color: AppTheme.slate400),
            const SizedBox(width: 4),
            Text(
              'Installing model files…',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.slate400),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Capability chip ────────────────────────────────────────────────────────
class _CapChip extends StatelessWidget {
  final String label;
  const _CapChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (label) {
      case 'vision':
        icon = Icons.remove_red_eye_rounded;
        color = const Color(0xFF60A5FA);
      case 'audio':
        icon = Icons.mic_rounded;
        color = const Color(0xFFA78BFA);
      default:
        icon = Icons.chat_rounded;
        color = AppTheme.amber400;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

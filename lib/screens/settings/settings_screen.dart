import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/hf_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/floating_orbs_background.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../models/ai_model.dart';
import '../../providers/model_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final modelState = ref.watch(modelProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── App bar ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Navigator.pop(context),
                          color: AppTheme.onSurface,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Settings',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Models section ───────────────────────────────────────
                _SectionHeader(label: 'Models'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  sliver: SliverList.builder(
                    itemCount: kAvailableModels.length,
                    itemBuilder: (_, i) {
                      final def = kAvailableModels[i];
                      final aiModel = modelState.models.firstWhere(
                        (m) => m.id == def.id,
                        orElse: () => AIModel(id: def.id),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ModelSettingsTile(
                          def: def,
                          aiModel: aiModel,
                          onDelete: () => _confirmDelete(
                              context, ref, def.id, def.displayName),
                        ),
                      );
                    },
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Customization section ────────────────────────────────
                _SectionHeader(label: 'Customization'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: FrostedGlassCard(
                      borderRadius: 20,
                      blur: 14,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Temperature
                          _SliderRow(
                            label: 'Temperature',
                            value: settings.temperature,
                            min: 0.1,
                            max: 2.0,
                            divisions: 19,
                            format: (v) => v.toStringAsFixed(1),
                            tooltip:
                                'Controls creativity. Lower = more focused, Higher = more creative.',
                            onChanged: (v) => ref
                                .read(settingsProvider.notifier)
                                .setTemperature(v),
                          ),
                          const Divider(height: 24),
                          // Top-P
                          _SliderRow(
                            label: 'Top-P',
                            value: settings.topP,
                            min: 0.1,
                            max: 1.0,
                            divisions: 18,
                            format: (v) => v.toStringAsFixed(2),
                            tooltip:
                                'Nucleus sampling. Lower = fewer token choices, more predictable.',
                            onChanged: (v) =>
                                ref.read(settingsProvider.notifier).setTopP(v),
                          ),
                          const Divider(height: 24),
                          // Top-K
                          _SliderRow(
                            label: 'Top-K',
                            value: settings.topK.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            format: (v) => v.toInt().toString(),
                            tooltip:
                                'Limits sampling to top K tokens. Lower = more conservative.',
                            onChanged: (v) => ref
                                .read(settingsProvider.notifier)
                                .setTopK(v.toInt()),
                          ),
                          const Divider(height: 24),
                          // Max tokens
                          _SliderRow(
                            label: 'Max Tokens',
                            value: settings.maxTokens.toDouble(),
                            min: 256,
                            max: 4096,
                            divisions: 15,
                            format: (v) => v.toInt().toString(),
                            tooltip:
                                'Maximum number of tokens the model will generate.',
                            onChanged: (v) => ref
                                .read(settingsProvider.notifier)
                                .setMaxTokens(v.toInt()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Developer section ────────────────────────────────────
                _SectionHeader(label: 'Developer'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: FrostedGlassCard(
                      borderRadius: 20,
                      blur: 14,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: _ToggleTile(
                        icon: Icons.bug_report_rounded,
                        label: 'Debug JSON Button',
                        subtitle:
                            'Show JSON response viewer in response screen',
                        tooltip:
                            'Turn on to show the JSON debug button in response view.',
                        value: settings.debugJsonEnabled,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .setDebugJsonEnabled(v),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Accessibility section ────────────────────────────────
                _SectionHeader(label: 'Accessibility'),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                  sliver: SliverToBoxAdapter(
                    child: FrostedGlassCard(
                      borderRadius: 20,
                      blur: 14,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        children: [
                          _ToggleTile(
                            icon: Icons.record_voice_over_rounded,
                            label: 'Text-to-Speech',
                            subtitle: 'Read repair steps aloud',
                            tooltip:
                                'Enable voice playback for generated repair guidance.',
                            value: settings.ttsEnabled,
                            onChanged: (v) => ref
                                .read(settingsProvider.notifier)
                                .setTtsEnabled(v),
                          ),
                          if (settings.ttsEnabled) ...[
                            const Divider(height: 0),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _SliderRow(
                                label: 'Speech Rate',
                                value: settings.speechRate,
                                min: 0.25,
                                max: 1.0,
                                divisions: 6,
                                format: (v) => '${(v * 100).toInt()}%',
                                tooltip: 'Speed of the TTS voice.',
                                onChanged: (v) => ref
                                    .read(settingsProvider.notifier)
                                    .setSpeechRate(v),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "$name"?'),
        content: const Text(
            'This removes all model files from your device. You can re-download later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      ref.read(modelProvider.notifier).deleteModel(id);
    }
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 0, 22, 10),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
        ),
      ),
    );
  }
}

// ── Model settings tile ───────────────────────────────────────────────────────
class _ModelSettingsTile extends StatelessWidget {
  final HFModelDef def;
  final AIModel aiModel;
  final VoidCallback onDelete;

  const _ModelSettingsTile({
    required this.def,
    required this.aiModel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = aiModel.status == ModelStatus.downloaded ||
        aiModel.status == ModelStatus.ready;

    return FrostedGlassCard(
      borderRadius: 18,
      blur: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(def.icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        )),
                Text(
                  isDownloaded
                      ? '${def.sizeLabel} · Downloaded'
                      : def.sizeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDownloaded
                            ? AppTheme.green400
                            : AppTheme.onSurfaceSub,
                      ),
                ),
              ],
            ),
          ),
          if (isDownloaded)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.red400,
              iconSize: 22,
              onPressed: onDelete,
              tooltip: 'Delete model',
            ),
        ],
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String tooltip;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tooltip,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              color: value ? AppTheme.primary : AppTheme.onSurfaceSub,
              size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: AppTheme.onSurface)),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: tooltip,
                      child: Icon(Icons.info_outline_rounded,
                          size: 14, color: AppTheme.onSurfaceSub),
                    ),
                  ],
                ),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.onSurfaceSub)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Slider row ────────────────────────────────────────────────────────────────
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final String tooltip;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.tooltip,
    required this.onChanged,
  });

  void _showInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$label info'),
        content: Text(tooltip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(width: 6),
                Tooltip(
                  message: tooltip,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    color: AppTheme.onSurfaceSub,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 24, height: 24),
                    onPressed: () => _showInfoDialog(context),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                format(value),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

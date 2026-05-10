import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/hf_models.dart';
import '../../core/utils/storage_utils.dart';
import '../../providers/settings_provider.dart';
import '../../providers/model_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final modelState = ref.watch(modelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Voice & TTS ───────────────────────────────────────────────────
          _SectionHeader('Voice & Speech'),
          _SettingCard(children: [
            SwitchListTile(
              title: const Text('Text-to-Speech'),
              subtitle: const Text('Read responses aloud'),
              value: settings.ttsEnabled,
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).setTtsEnabled(v),
              secondary: const Icon(Icons.volume_up_rounded),
            ),
            if (settings.ttsEnabled) ...[
              const Divider(indent: 16, endIndent: 16),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Speech Speed',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(_speedLabel(settings.speechRate),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.amber400)),
                      ],
                    ),
                    Slider(
                      value: settings.speechRate,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      onChanged: (v) =>
                          ref.read(settingsProvider.notifier).setSpeechRate(v),
                    ),
                  ],
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── Inference settings ────────────────────────────────────────────
          _SectionHeader('AI Settings'),
          _SettingCard(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Context Window',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'How much conversation the AI remembers. Larger = more RAM.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.slate400),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1024, label: Text('1K')),
                      ButtonSegment(value: 2048, label: Text('2K')),
                      ButtonSegment(value: 4096, label: Text('4K')),
                    ],
                    selected: {settings.contextSize},
                    onSelectionChanged: (s) => ref
                        .read(settingsProvider.notifier)
                        .setContextSize(s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor:
                          AppTheme.amber500.withOpacity(0.15),
                      selectedForegroundColor: AppTheme.amber400,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: const Text('Hugging Face Token'),
              subtitle: Text(
                settings.hasHfToken
                    ? 'Token saved. Used for model downloads.'
                    : 'Optional. Helps with gated or rate-limited downloads.',
              ),
              trailing: TextButton(
                onPressed: () => _showHfTokenDialog(
                  context,
                  settings.hfToken ?? '',
                  ref.read(settingsProvider.notifier),
                ),
                child: Text(settings.hasHfToken ? 'Edit' : 'Add'),
              ),
            ),
            if (settings.hasHfToken)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(settingsProvider.notifier).clearHfToken(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove token'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.red400,
                    ),
                  ),
                ),
              ),
          ]),

          const SizedBox(height: 16),

          // ── Models ────────────────────────────────────────────────────────
          _SectionHeader('Installed Models'),
          ...modelState.models.map((model) {
            final def = model.def;
            if (def == null) return const SizedBox.shrink();
            return _ModelSettingCard(model: model, def: def);
          }),

          const SizedBox(height: 16),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingCard(children: [
            ListTile(
              leading: const Icon(Icons.build_circle_rounded,
                  color: AppTheme.amber400),
              title: const Text('FixGemma'),
              subtitle: const Text('Version 1.0.0'),
              trailing: const Text('1.0.0',
                  style: TextStyle(color: AppTheme.slate400, fontSize: 12)),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.memory_rounded),
              title: const Text('AI Engine'),
              subtitle: const Text('Cactus on-device inference'),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Privacy'),
              subtitle: const Text(
                  'Everything runs on your device. No data is sent to the cloud.'),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _speedLabel(double rate) {
    if (rate < 0.4) return 'Very Slow';
    if (rate < 0.5) return 'Slow';
    if (rate < 0.65) return 'Normal';
    if (rate < 0.8) return 'Fast';
    return 'Very Fast';
  }

  Future<void> _showHfTokenDialog(
    BuildContext context,
    String currentToken,
    SettingsNotifier notifier,
  ) async {
    final token = await showDialog<String>(
      context: context,
      builder: (_) => _HfTokenDialog(initialToken: currentToken),
    );

    if (token != null) {
      await notifier.setHfToken(token);
    }
  }
}

class _HfTokenDialog extends StatefulWidget {
  final String initialToken;

  const _HfTokenDialog({required this.initialToken});

  @override
  State<_HfTokenDialog> createState() => _HfTokenDialogState();
}

class _HfTokenDialogState extends State<_HfTokenDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hugging Face Token'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'HF access token',
          hintText: 'hf_...',
          helperText: 'Create one at huggingface.co/settings/tokens',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ModelSettingCard extends ConsumerWidget {
  final dynamic model;
  final HFModelDef def;

  const _ModelSettingCard({
    required this.model,
    required this.def,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(def.icon, color: AppTheme.amber400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(def.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.slate100,
                          )),
                ),
                _StatusBadge(status: model.status),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: StorageUtils.getModelSize(model.id),
              builder: (_, snap) {
                final size = snap.data ?? 0;
                return Text(
                  size > 0
                      ? 'Installed: ${StorageUtils.formatBytes(size)}'
                      : 'Not installed',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
            if (model.isDownloaded) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red400,
                  side: const BorderSide(color: AppTheme.red400),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${def.displayName}?'),
        content: const Text(
            'The model files will be deleted. You\'ll need to re-download to use it again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.red500),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(modelProvider.notifier).deleteModel(def.id);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final dynamic status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Using status.name string comparison to be type-safe
    final name = status.toString().split('.').last;
    final (color, label) = switch (name) {
      'ready' => (AppTheme.green400, 'Active'),
      'downloaded' => (AppTheme.slate400, 'Installed'),
      'downloading' => (AppTheme.amber400, 'Downloading'),
      'error' => (AppTheme.red400, 'Error'),
      _ => (AppTheme.slate700, 'Not installed'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.slate400,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.slate800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate700),
      ),
      child: Column(children: children),
    );
  }
}

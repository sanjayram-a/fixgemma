import 'package:flutter/material.dart';

/// HuggingFace model definition
class HFModelDef {
  final String id;
  final String repoId;
  final String displayName;
  final String description;
  final int sizeBytes;
  final List<String> capabilities; // "text", "vision", "audio"
  final String quantization;
  final IconData icon;
  final bool isComingSoon;

  const HFModelDef({
    required this.id,
    required this.repoId,
    required this.displayName,
    required this.description,
    required this.sizeBytes,
    required this.capabilities,
    required this.quantization,
    required this.icon,
    this.isComingSoon = false,
  });

  String get sizeLabel {
    final gb = sizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} GB';
  }

  /// HuggingFace resolve URL for a specific file
  String fileUrl(String filename) =>
      'https://huggingface.co/$repoId/resolve/main/$filename';

  /// HuggingFace API URL to list all files
  String get apiUrl => 'https://huggingface.co/api/models/$repoId';
}

/// All available models
const List<HFModelDef> kAvailableModels = [
  HFModelDef(
    id: 'fixgemma4-e4b-int4',
    repoId: 'sanjayram-a/fixgemma4-e4b-cact-INT4-zip', // zip-based repo
    displayName: 'FixGemma 4 E4B',
    description:
        'Full repair assistant. Understands text, photos, and voice. '
        'Best for complex appliance issues and step-by-step guidance.',
    sizeBytes: 6930333114,
    capabilities: ['text', 'vision', 'audio'],
    quantization: 'INT4',
    icon: Icons.build_rounded,
  ),
  HFModelDef(
    id: 'fixgemma-lite',
    repoId: 'sanjayram-a/fixgemma4-e2b-cact-INT4-zip',
    displayName: 'FixGemma Lite',
    description:
        'Compact 2B model, text-only. Faster downloads, lower RAM usage. '
        'Great for quick questions and simple troubleshooting.',
    sizeBytes: 4043595549,
    capabilities: ['text'],
    quantization: 'INT4',
    icon: Icons.bolt_rounded,
  ),
];

/// Find model by id
HFModelDef? modelById(String id) =>
    kAvailableModels.cast<HFModelDef?>().firstWhere(
      (m) => m?.id == id,
      orElse: () => null,
    );

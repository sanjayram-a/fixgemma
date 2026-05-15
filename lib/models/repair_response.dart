import 'dart:convert';

/// A single repair step from the model's structured JSON response.
class RepairStep {
  final int number;
  final String title;
  final String description;
  final String? warning;

  const RepairStep({
    required this.number,
    required this.title,
    required this.description,
    this.warning,
  });

  factory RepairStep.fromJson(Map<String, dynamic> j) => RepairStep(
        number: j['number'] as int? ?? 0,
        title: j['title'] as String? ?? 'Step',
        description: j['description'] as String? ?? '',
        // Coerce empty string → null so callers can use a simple null-check
        warning:
            j['warning'] is String && (j['warning'] as String).trim().isNotEmpty
                ? j['warning'] as String
                : null,
      );
}

/// The full structured response the model produces.
/// Fields are nullable because the response streams in incrementally.
class RepairResponse {
  final String? safetyMessage;
  final List<String>? toolsRequired;
  final List<RepairStep> steps;
  final List<String>? tips;
  final bool isComplete;

  const RepairResponse({
    this.safetyMessage,
    this.toolsRequired,
    this.steps = const [],
    this.tips,
    this.isComplete = false,
  });

  RepairResponse copyWith({
    String? safetyMessage,
    List<String>? toolsRequired,
    List<RepairStep>? steps,
    List<String>? tips,
    bool? isComplete,
  }) =>
      RepairResponse(
        safetyMessage: safetyMessage ?? this.safetyMessage,
        toolsRequired: toolsRequired ?? this.toolsRequired,
        steps: steps ?? this.steps,
        tips: tips ?? this.tips,
        isComplete: isComplete ?? this.isComplete,
      );
}

/// Incrementally parses streaming JSON tokens into a [RepairResponse].
///
/// Strategy:
///  1. Strip any markdown fences from the buffer.
///  2. On every token, run the lightweight partial-field extractor so that
///     `safety`, `tools`, and every complete `step` object are emitted as
///     soon as the closing `}` of that object arrives in the stream.
///  3. On `finalize()` run a full `jsonDecode` for a clean final state.
class RepairResponseParser {
  final StringBuffer _buffer = StringBuffer();
  RepairResponse _current = const RepairResponse();

  /// Feed a new streaming token. Returns the latest [RepairResponse].
  RepairResponse feed(String token) {
    _buffer.write(token);
    // Always run the partial extractor — it is cheap and gets steps ASAP.
    _current = _extractPartial(_buffer.toString(), isComplete: false);
    return _current;
  }

  /// Call once the stream ends for a final, authoritative parse.
  RepairResponse finalize() {
    final raw = _buffer.toString();
    // Prefer full JSON decode; fall back to partial extractor.
    final cleaned = _removeTrailingCommas(_stripFences(raw));
    try {
      final j = jsonDecode(cleaned) as Map<String, dynamic>;
      _current = _fromFullJson(j, isComplete: true);
    } catch (_) {
      _current = _extractPartial(raw, isComplete: true);
    }
    return _current;
  }

  // ── Partial extractor ──────────────────────────────────────────────────────

  RepairResponse _extractPartial(String raw, {required bool isComplete}) {
    final s = _stripFences(raw);

    // ── safety ─────────────────────────────────────────────────────────────
    String? safety = _current.safetyMessage;
    final safetyM = RegExp(r'"safety"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(s);
    if (safetyM != null) safety = _unescape(safetyM.group(1)!);

    // ── tools ──────────────────────────────────────────────────────────────
    List<String>? tools = _current.toolsRequired;
    final toolsM =
        RegExp(r'"tools"\s*:\s*\[(.*?)\]', dotAll: true).firstMatch(s);
    if (toolsM != null) {
      final inner = toolsM.group(1)!;
      tools = RegExp(r'"((?:[^"\\]|\\.)*)"')
          .allMatches(inner)
          .map((m) => _unescape(m.group(1)!))
          .toList();
    }

    // ── steps — extract every COMPLETE step object that has arrived ────────
    final steps = _extractCompleteSteps(s);

    // ── tips ───────────────────────────────────────────────────────────────
    List<String>? tips = _current.tips;
    final tipsM = RegExp(r'"tips"\s*:\s*\[(.*?)\]', dotAll: true).firstMatch(s);
    if (tipsM != null) {
      final inner = tipsM.group(1)!;
      tips = RegExp(r'"((?:[^"\\]|\\.)*)"')
          .allMatches(inner)
          .map((m) => _unescape(m.group(1)!))
          .toList();
    }

    return RepairResponse(
      safetyMessage: safety,
      toolsRequired: tools,
      steps: steps.isNotEmpty ? steps : _current.steps,
      tips: tips,
      isComplete: isComplete,
    );
  }

  /// Find the "steps" array in [src] then walk it character-by-character to
  /// collect every complete step object `{ … }` (including nested braces).
  List<RepairStep> _extractCompleteSteps(String src) {
    // Locate the start of the steps array.
    final arrayStart = _findStepsArrayStart(src);
    if (arrayStart < 0) return [];

    final steps = <RepairStep>[];
    int i = arrayStart;
    final len = src.length;

    while (i < len) {
      // Find next '{' that begins a step object.
      while (i < len && src[i] != '{') {
        // If we hit ']' at top level, the array is done.
        if (src[i] == ']') return steps;
        i++;
      }
      if (i >= len) break;

      // Walk matching braces to find closing '}'.
      int depth = 0;
      final objStart = i;
      int objEnd = -1;
      bool inString = false;
      bool escape = false;

      while (i < len) {
        final ch = src[i];
        if (escape) {
          escape = false;
        } else if (ch == '\\' && inString) {
          escape = true;
        } else if (ch == '"') {
          inString = !inString;
        } else if (!inString) {
          if (ch == '{') depth++;
          if (ch == '}') {
            depth--;
            if (depth == 0) {
              objEnd = i;
              break;
            }
          }
        }
        i++;
      }

      if (objEnd < 0) break; // Incomplete object — stream not done yet.

      final objStr = src.substring(objStart, objEnd + 1);
      try {
        final j = jsonDecode(objStr) as Map<String, dynamic>;
        steps.add(RepairStep.fromJson(j));
      } catch (_) {
        try {
          final fixed = _removeTrailingCommas(objStr);
          final j = jsonDecode(fixed) as Map<String, dynamic>;
          steps.add(RepairStep.fromJson(j));
        } catch (_) {
          // Malformed object — skip it.
        }
      }
      i = objEnd + 1;
    }

    return steps;
  }

  /// Returns the index just after `"steps": [` in [src], or -1.
  int _findStepsArrayStart(String src) {
    final m = RegExp(r'"steps"\s*:\s*\[').firstMatch(src);
    if (m == null) return -1;
    return m.end; // index right after '['
  }

  // ── Full JSON decode (used in finalize) ────────────────────────────────────

  RepairResponse _fromFullJson(Map<String, dynamic> j,
      {required bool isComplete}) {
    // Normalise "" → null so _buildCards can skip the card
    final safetyRaw = j['safety'] as String?;
    String? safety =
        (safetyRaw != null && safetyRaw.trim().isNotEmpty) ? safetyRaw : null;

    List<String>? tools;
    final toolsRaw = j['tools'];
    if (toolsRaw is List) {
      final t = toolsRaw
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (t.isNotEmpty) tools = t;
    }

    List<RepairStep> steps = [];
    final stepsRaw = j['steps'];
    if (stepsRaw is List) {
      for (final s in stepsRaw) {
        if (s is Map<String, dynamic>) steps.add(RepairStep.fromJson(s));
      }
    }

    List<String>? tips;
    final tipsRaw = j['tips'];
    if (tipsRaw is List) {
      final t = tipsRaw
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (t.isNotEmpty) tips = t;
    }

    return RepairResponse(
      safetyMessage: safety,
      toolsRequired: tools,
      steps: steps,
      tips: tips,
      isComplete: isComplete,
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  /// Strip markdown code fences (```json … ```) if present.
  String _stripFences(String raw) {
    return raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
  }

  /// Remove JSON trailing commas before closing braces/brackets.
  String _removeTrailingCommas(String input) {
    var out = input;
    while (true) {
      final next = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
      if (next == out) return out;
      out = next;
    }
  }

  /// Basic JSON string unescaping for captured regex groups.
  String _unescape(String s) => s
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', '\\')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\t', '\t');

  String get rawBuffer => _buffer.toString();

  void reset() {
    _buffer.clear();
    _current = const RepairResponse();
  }
}

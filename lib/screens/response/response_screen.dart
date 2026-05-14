import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/floating_orbs_background.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';

class ResponseScreen extends ConsumerStatefulWidget {
  const ResponseScreen({super.key});

  @override
  ConsumerState<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends ConsumerState<ResponseScreen> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  int _prevCardCount = 0;
  int? _speakingCardPage;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).stopTtsPlayback();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final cards = chatState.cards;
    final isStreaming = chatState.isStreaming;
    final messages = chatState.messages;
    final showDebugJson = ref.watch(settingsProvider).debugJsonEnabled;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Auto-scroll to newest card during streaming
    if (cards.length > _prevCardCount && isStreaming && _prevCardCount > 0) {
      if (_currentPage >= _prevCardCount - 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageCtrl.hasClients) {
            _pageCtrl.animateToPage(
              cards.length - 1,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
    _prevCardCount = cards.length;

    // Build all cards: prompt card first, then response cards
    final userMsg = messages.isNotEmpty
        ? messages.firstWhere((m) => m.role == 'user',
            orElse: () => messages.first)
        : null;

    // Total pages = 1 prompt card + response cards
    final totalPages = 1 + cards.length;
    final clampedPage = _currentPage.clamp(0, totalPages - 1);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Stack(
        children: [
          const FloatingOrbsBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.pop(context),
                        color: AppTheme.onSurface,
                        iconSize: 20,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userMsg != null)
                              Text(
                                _truncate(
                                    userMsg.content.isNotEmpty
                                        ? userMsg.content
                                        : (userMsg.imagePaths?.isNotEmpty ==
                                                true
                                            ? '📷 Image repair'
                                            : userMsg.audioPath != null
                                                ? '🎙 Voice repair'
                                                : 'Repair'),
                                    48),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.onSurface,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              chatState.activeSession?.modelId ?? 'FixGemma',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.onSurfaceSub),
                            ),
                          ],
                        ),
                      ),
                      if (isStreaming)
                        LoadingAnimationWidget.progressiveDots(
                          color: AppTheme.primary,
                          size: 28,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Card carousel ─────────────────────────────────────────
                Expanded(
                  child: cards.isEmpty && !isStreaming
                      ? _EmptyState(isStreaming: isStreaming)
                      : PageView.builder(
                          controller: _pageCtrl,
                          itemCount: totalPages,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemBuilder: (_, i) {
                            // Page 0 = prompt card
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: _PromptCard(
                                  message: userMsg,
                                  index: 0,
                                  total: totalPages,
                                ),
                              );
                            }
                            // Pages 1..N = response cards
                            final cardIdx = i - 1;
                            if (cardIdx >= cards.length) {
                              return _LoadingCard();
                            }
                            final card = cards[cardIdx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: card.isLoading
                                  ? _LoadingCard()
                                  : card.type == RepairCardType.followUp
                                      ? _FollowUpCard(
                                          onSubmit: (text) =>
                                              _sendFollowUp(text))
                                      : _RepairCard(
                                          card: card,
                                          index: i,
                                          total: totalPages,
                                          isSpeaking: _speakingCardPage == i,
                                          onToggleSpeak: () =>
                                              _toggleCardSpeech(i, card),
                                        ),
                            );
                          },
                        ),
                ),

                // ── Navigation row ─────────────────────────────────────────
                if (totalPages > 1 || isStreaming)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _NavArrow(
                          icon: Icons.chevron_left_rounded,
                          enabled: clampedPage > 0,
                          onTap: () {
                            _pageCtrl.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic);
                          },
                        ),
                        const SizedBox(width: 16),
                        _DotIndicator(
                          count: totalPages,
                          current: clampedPage,
                        ),
                        const SizedBox(width: 16),
                        _NavArrow(
                          icon: Icons.chevron_right_rounded,
                          enabled: clampedPage < totalPages - 1,
                          onTap: () {
                            _pageCtrl.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic);
                          },
                        ),
                      ],
                    ),
                  ),

                // ── Debug button / spacer ─────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: showDebugJson
                      ? Padding(
                          key: const ValueKey('debug-button'),
                          padding:
                              EdgeInsets.fromLTRB(16, 6, 16, bottomInset + 10),
                          child: GestureDetector(
                            onTap: () => _showRawJsonDebug(
                                context, chatState.streamingText),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isStreaming
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : AppTheme.tertiary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isStreaming
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : AppTheme.tertiary
                                          .withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.data_object_rounded,
                                    size: 13,
                                    color: isStreaming
                                        ? AppTheme.primary
                                        : AppTheme.onSurfaceSub,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isStreaming
                                        ? 'Debug  •  streaming…'
                                        : 'Debug JSON',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isStreaming
                                          ? AppTheme.primary
                                          : AppTheme.onSurfaceSub,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('debug-spacer'),
                          height: bottomInset + 36,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFollowUp(String text) async {
    if (text.trim().isEmpty) return;

    final currentCards = ref.read(chatProvider).cards;
    final baseCards =
        currentCards.where((c) => c.type != RepairCardType.followUp).toList();
    final firstNewIdx = 1 + baseCards.length; // +1 for prompt card

    await ref.read(chatProvider.notifier).sendMessage(
          text,
          appendTo: baseCards,
        );
    if (!mounted) return;

    final count = ref.read(chatProvider).cards.length;
    if (count > baseCards.length) {
      _pageCtrl.animateToPage(
        firstNewIdx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _toggleCardSpeech(int pageIndex, RepairCard card) async {
    final notifier = ref.read(chatProvider.notifier);

    if (_speakingCardPage == pageIndex) {
      await notifier.stopTtsPlayback();
      if (mounted) setState(() => _speakingCardPage = null);
      return;
    }

    await notifier.stopTtsPlayback();
    if (!mounted) return;
    setState(() => _speakingCardPage = pageIndex);

    final text = '${card.title}. ${card.body}'.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _speakingCardPage = null);
      return;
    }

    try {
      await notifier.speakText(text);
    } finally {
      if (mounted && _speakingCardPage == pageIndex) {
        setState(() => _speakingCardPage = null);
      }
    }
  }

  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  void _showRawJsonDebug(BuildContext context, String? initialBuffer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RawJsonDebugSheet(initialBuffer: initialBuffer),
    );
  }
}

// ── Prompt card ──────────────────────────────────────────────────────────────
class _PromptCard extends StatelessWidget {
  final dynamic message; // AppMessage?
  final int index;
  final int total;

  const _PromptCard({this.message, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final hasImages =
        message?.imagePaths != null && (message.imagePaths as List).isNotEmpty;
    final hasAudio = message?.audioPath != null;
    final text = (message?.content as String? ?? '').trim();

    return FrostedGlassCard(
      borderRadius: 26,
      blur: 18,
      borderColor: AppTheme.secondary.withValues(alpha: 0.35),
      bgColor: Colors.white.withValues(alpha: 0.75),
      shadows: [
        BoxShadow(
          color: AppTheme.secondary.withValues(alpha: 0.15),
          blurRadius: 30,
          offset: const Offset(0, 8),
        )
      ],
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded,
                      color: AppTheme.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Request',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1} / $total',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.secondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Divider(
                color: AppTheme.secondary.withValues(alpha: 0.2), thickness: 1),
            const SizedBox(height: 14),

            // Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      Text(
                        text,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.onSurface,
                              height: 1.65,
                            ),
                      ),
                    if (hasAudio && text.isEmpty)
                      _InlineAudioPlayer(
                        filePath: message.audioPath as String,
                      ),
                    if (hasImages) ...[
                      if (text.isNotEmpty || hasAudio)
                        const SizedBox(height: 14),
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              (message.imagePaths as List<String>).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final path =
                                (message.imagePaths as List<String>)[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(path),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 90,
                                  height: 90,
                                  color:
                                      AppTheme.tertiary.withValues(alpha: 0.3),
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: AppTheme.onSurfaceSub),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAudioPlayer extends StatefulWidget {
  final String filePath;
  const _InlineAudioPlayer({required this.filePath});

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _durationSub = _player.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur);
    });
  }

  @override
  void didUpdateWidget(covariant _InlineAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _player.stop();
      _position = Duration.zero;
      _duration = Duration.zero;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.stop();
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(widget.filePath));
  }

  Future<void> _seek(double ms) async {
    await _player.seek(Duration(milliseconds: ms.round()));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = (_duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds)
        .toDouble();
    final valueMs = _position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: AppTheme.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Voice prompt',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.onSurface),
                ),
              ),
              IconButton(
                onPressed: _toggle,
                icon: Icon(
                  _isPlaying
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_fill_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                tooltip: _isPlaying ? 'Stop' : 'Play',
              ),
            ],
          ),
          Slider(
            value: valueMs,
            max: maxMs,
            onChanged: _seek,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '${_fmt(_position)} / ${_fmt(_duration)}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.onSurfaceSub),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual repair card ───────────────────────────────────────────────────
class _RepairCard extends StatefulWidget {
  final RepairCard card;
  final int index;
  final int total;
  final bool isSpeaking;
  final VoidCallback onToggleSpeak;

  const _RepairCard({
    required this.card,
    required this.index,
    required this.total,
    required this.isSpeaking,
    required this.onToggleSpeak,
  });

  @override
  State<_RepairCard> createState() => _RepairCardState();
}

class _RepairCardState extends State<_RepairCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final ScrollController _bodyScroll;
  bool _showScrollHint = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _bodyScroll = ScrollController()..addListener(_updateScrollHint);
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollHint());
  }

  @override
  void dispose() {
    _bodyScroll
      ..removeListener(_updateScrollHint)
      ..dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _updateScrollHint() {
    if (!_bodyScroll.hasClients) return;
    final max = _bodyScroll.position.maxScrollExtent;
    final show = max > 8 && _bodyScroll.offset < max - 8;
    if (show != _showScrollHint && mounted) {
      setState(() => _showScrollHint = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (Color accentColor, IconData icon) = _cardStyle(widget.card.type);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: FrostedGlassCard(
          borderRadius: 26,
          blur: 18,
          borderColor: accentColor.withValues(alpha: 0.35),
          bgColor: Colors.white.withValues(alpha: 0.75),
          shadows: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            )
          ],
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.card.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.index + 1} / ${widget.total}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: widget.onToggleSpeak,
                      icon: Icon(
                        widget.isSpeaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 20,
                      ),
                      color: accentColor,
                      tooltip:
                          widget.isSpeaking ? 'Stop reading' : 'Read this card',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(
                    color: accentColor.withValues(alpha: 0.2), thickness: 1),
                const SizedBox(height: 14),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _bodyScroll,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Text(
                          widget.card.body,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.onSurface,
                                    height: 1.65,
                                  ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _showScrollHint ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.9),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: AppTheme.onSurfaceSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData) _cardStyle(RepairCardType type) {
    return switch (type) {
      RepairCardType.safety => (AppTheme.red400, Icons.warning_rounded),
      RepairCardType.tools => (
          const Color(0xFF7C5CBF),
          Icons.build_circle_rounded
        ),
      RepairCardType.step => (
          AppTheme.primary,
          Icons.check_circle_outline_rounded
        ),
      RepairCardType.tips => (AppTheme.green400, Icons.lightbulb_rounded),
      _ => (AppTheme.tertiary, Icons.info_rounded),
    };
  }
}

// ── Loading placeholder card ─────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      borderRadius: 26,
      blur: 18,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingAnimationWidget.staggeredDotsWave(
                color: AppTheme.primary, size: 48),
            const SizedBox(height: 16),
            Text('Generating next step…',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.onSurfaceSub)),
          ],
        ),
      ),
    );
  }
}

// ── Follow-up input card ─────────────────────────────────────────────────────
class _FollowUpCard extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;
  const _FollowUpCard({required this.onSubmit});

  @override
  State<_FollowUpCard> createState() => _FollowUpCardState();
}

class _FollowUpCardState extends State<_FollowUpCard> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _focusNode.unfocus();
    setState(() => _sending = true);
    await widget.onSubmit(text);
    _ctrl.clear();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return FrostedGlassCard(
      borderRadius: 26,
      blur: 18,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded,
                        color: AppTheme.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Any Questions?',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(
                  color: AppTheme.secondary.withValues(alpha: 0.2),
                  thickness: 1),
              const SizedBox(height: 12),

              Text(
                'Ask a follow-up question about this repair',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.onSurfaceSub),
              ),
              const SizedBox(height: 12),

              // Text field — fixed height, no expands so keyboard push works
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.tertiary),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'e.g. What if I don\'t have a multimeter?',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.onSurfaceSub),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sending ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ask',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Navigation arrow ─────────────────────────────────────────────────────────
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavArrow(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.tertiary.withValues(alpha: 0.15),
          border: Border.all(
              color: enabled
                  ? AppTheme.primary.withValues(alpha: 0.35)
                  : AppTheme.tertiary.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          color: enabled ? AppTheme.primary : AppTheme.onSurfaceSub,
          size: 28,
        ),
      ),
    );
  }
}

// ── Dot indicator ────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 7;
    final dots = count.clamp(0, maxVisible);
    // Slide the window so current dot is always visible
    final offset = (current - (maxVisible ~/ 2))
        .clamp(0, (count - maxVisible).clamp(0, count));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dots, (i) {
        final realIdx = i + offset;
        final isActive = realIdx == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? AppTheme.primary
                : AppTheme.tertiary.withValues(alpha: 0.6),
          ),
        );
      }),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool isStreaming;
  const _EmptyState({required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FrostedGlassCard(
          borderRadius: 22,
          blur: 14,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isStreaming)
                LoadingAnimationWidget.fourRotatingDots(
                    color: AppTheme.primary, size: 48)
              else
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.tertiary, size: 48),
              const SizedBox(height: 16),
              Text(
                isStreaming ? 'Building your repair guide…' : 'No response yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.onSurfaceSub,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// \u2500\u2500 Raw JSON debug bottom sheet \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
class _RawJsonDebugSheet extends ConsumerStatefulWidget {
  final String? initialBuffer;
  const _RawJsonDebugSheet({this.initialBuffer});

  @override
  ConsumerState<_RawJsonDebugSheet> createState() => _RawJsonDebugSheetState();
}

class _RawJsonDebugSheetState extends ConsumerState<_RawJsonDebugSheet> {
  final ScrollController _scroll = ScrollController();
  bool _autoScroll = true;
  bool _copied = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (_autoScroll && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isStreaming = chatState.isStreaming;
    // Prefer live streamingText; fall back to the last assistant message
    final rawJson = chatState.streamingText ??
        (chatState.messages.isNotEmpty
            ? chatState.messages
                .lastWhere((m) => m.role == 'assistant',
                    orElse: () => chatState.messages.last)
                .content
            : widget.initialBuffer ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sheetScroll) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D14).withValues(alpha: 0.92),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                    child: Row(
                      children: [
                        Icon(Icons.data_object_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Raw JSON Stream',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Live badge
                        if (isStreaming) _LiveBadge(),
                        const Spacer(),
                        // Auto-scroll toggle
                        GestureDetector(
                          onTap: () =>
                              setState(() => _autoScroll = !_autoScroll),
                          child: Tooltip(
                            message: _autoScroll
                                ? 'Auto-scroll ON'
                                : 'Auto-scroll OFF',
                            child: Icon(
                              _autoScroll
                                  ? Icons.vertical_align_bottom_rounded
                                  : Icons.pause_rounded,
                              color: _autoScroll
                                  ? AppTheme.primary
                                  : Colors.white38,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Copy button
                        GestureDetector(
                          onTap: () => _copyToClipboard(rawJson),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              key: ValueKey(_copied),
                              color:
                                  _copied ? AppTheme.green400 : Colors.white54,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                      color: Colors.white.withValues(alpha: 0.07), height: 1),

                  // JSON content
                  Expanded(
                    child: rawJson.isEmpty
                        ? Center(
                            child: Text(
                              'No data yet…',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                          )
                        : Scrollbar(
                            controller: _scroll,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              child: SelectableText(
                                rawJson,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  color: Color(0xFF9CDCFE),
                                  height: 1.55,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                  ),

                  // Status bar
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
                    color: Colors.white.withValues(alpha: 0.03),
                    child: Text(
                      '${rawJson.length} chars  \u2022  '
                      '${rawJson.split('\n').length} lines'
                      '${isStreaming ? '  \u2022  streaming…' : '  \u2022  complete'}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Pulsing LIVE badge
class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.5), width: 1),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

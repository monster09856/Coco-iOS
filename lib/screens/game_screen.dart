import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:patpat_game/ads/ad_manager.dart';
import 'package:patpat_game/game/game_controller.dart';
import 'package:patpat_game/game/level_generator.dart';
import 'package:patpat_game/game/tutorial_manager.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/models/position.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/booster_bar.dart';
import 'package:patpat_game/widgets/combo_text.dart';
import 'package:patpat_game/widgets/game_board.dart';
import 'package:patpat_game/widgets/game_hud.dart';
import 'package:patpat_game/widgets/game_over_overlay.dart';
import 'package:patpat_game/widgets/level_complete_overlay.dart';
import 'package:patpat_game/widgets/level_objective_banner.dart';
import 'package:patpat_game/widgets/level_start_greeting.dart';
import 'package:patpat_game/widgets/level_transition_overlay.dart';
import 'package:patpat_game/widgets/world_map_flyover_overlay.dart';
import 'package:patpat_game/widgets/score_popup.dart';
import 'package:patpat_game/widgets/score_progress_bar.dart';
import 'package:patpat_game/widgets/tropical/island_button.dart';
import 'package:patpat_game/widgets/tropical/island_panel.dart';
import 'package:patpat_game/widgets/tutorial_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  final int level;
  const GameScreen({super.key, required this.level});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  late final GameController _controller;
  late final TutorialManager _tutorial;
  late final AnimationController _shake;
  int _lastComboCount = 0;
  bool _showTransition = false;
  // Combo banner display — auto-hides after a brief moment.
  int? _displayedCombo;
  Timer? _comboHideTimer;
  // Skip ("Atla") button — appears when cascade has been busy for a while.
  bool _skipBtnVisible = false;
  Timer? _skipBtnTimer;
  GameState _lastState = GameState.idle;

  // Floating "+N" score popups + screen shake.
  final List<_ScorePopupData> _popups = [];
  int _popupSeq = 0;
  // Board layout — captured by the LayoutBuilder around GameBoard so we
  // can translate (row,col) → screen pixels for popups.
  Rect? _boardRect;
  // Big-event screen shake (separate from combo shake).
  late final AnimationController _bigShake;
  double _bigShakeIntensity = 0;

  // Level-start mascot greeting overlay — shown once at level open.
  bool _showGreeting = true;
  String? _statusBannerText;
  Timer? _statusBannerTimer;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    _controller.addListener(_onChange);
    _controller.onStatusBanner = (msg) {
      if (!mounted) return;
      setState(() => _statusBannerText = msg);
      _statusBannerTimer?.cancel();
      _statusBannerTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _statusBannerText = null);
      });
    };
    // Decrement player's booster count when the controller fires its effect.
    _controller.onBoosterUsed = (type) {
      ref.read(playerProgressProvider.notifier).consumeBooster(type);
      // Visual flair for +3 moves: bounce "+3" chip near moves counter.
      if (type == BoosterType.extraMoves) {
        _triggerExtraMovesPop();
      }
    };
    _controller.onScorePopup = _spawnScorePopup;
    _controller.onScreenShake = _triggerBigShake;
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _bigShake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    final progress = ref.read(playerProgressProvider);
    _showGreeting = widget.level == 1 && !progress.tutorialCompleted;
    _tutorial = TutorialManager(startCompleted: progress.tutorialCompleted);
    _startLevel(widget.level);
  }

  void _startLevel(int level) {
    final cfg = LevelGenerator.generate(level);
    _controller.startLevel(cfg);
  }

  void _onChange() {
    if (!mounted) return;
    // First-time entry into gameOver consumes a life (life is no longer
    // burned on level start). Idempotent against repeated _onChange calls
    // because we gate on _lastState != gameOver.
    if (_controller.state == GameState.gameOver &&
        _lastState != GameState.gameOver) {
      ref.read(playerProgressProvider.notifier).loseLevel();
    }
    // Trigger combo shake + show combo banner when comboCount climbs.
    if (_controller.comboCount >= 2 && _controller.comboCount != _lastComboCount) {
      _shake.forward(from: 0);
      _displayedCombo = _controller.comboCount;
      _comboHideTimer?.cancel();
      _comboHideTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _displayedCombo = null);
      });
    }
    _lastComboCount = _controller.comboCount;
    _updateSkipBtn();
    setState(() {});
  }

  /// Show the "Atla" button only after the board has been busy (non-idle,
  /// non-paused, non-terminal) for ~1.4s — short cascades shouldn't surface
  /// a skip button, only the long ones that drag.
  void _updateSkipBtn() {
    final s = _controller.state;
    final busy = s == GameState.swapping ||
        s == GameState.destroying ||
        s == GameState.falling ||
        s == GameState.refilling;

    if (busy && _lastState != s) {
      // entering a busy phase from idle — start fresh delay timer
      _skipBtnTimer?.cancel();
      _skipBtnTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted &&
            _controller.state != GameState.idle &&
            _controller.state != GameState.paused &&
            _controller.state != GameState.gameOver &&
            _controller.state != GameState.levelComplete) {
          setState(() => _skipBtnVisible = true);
        }
      });
    } else if (!busy && _skipBtnVisible) {
      _skipBtnVisible = false;
    } else if (!busy) {
      _skipBtnTimer?.cancel();
    }
    _lastState = s;
  }

  void _onSkipPressed() {
    _controller.skipCascade();
    setState(() => _skipBtnVisible = false);
  }

  /// Picks between the short level→level transition (1.8s) and the long
  /// region/island intro (5.5s) depending on whether the next level
  /// crosses a region boundary. Region boundaries land on level 21, 41,
  /// 61, …, 241 — i.e. `nextLevel % 20 == 1` for nextLevel > 1.
  Widget _buildTransitionOverlay() {
    final nextLevel = widget.level + 1;
    final crossesRegion = nextLevel > 1 && nextLevel % 20 == 1;

    void onFinished() {
      final p = ref.read(playerProgressProvider);
      final adsDisabled = p.removeAdsPurchased || p.vipActive;
      if (!adsDisabled && AdManager.instance.shouldShowInterstitial()) {
        AdManager.instance.showInterstitialAd(
          onDismissed: () {
            if (mounted) context.go('/map');
          },
        );
      } else {
        if (mounted) context.go('/map');
      }
    }

    if (crossesRegion) {
      // Region complete — show the cinematic world map flyover. Coco flies
      // from the completed island to the new one while the golden trail
      // lights up segment by segment. ~6.5s.
      return WorldMapFlyoverOverlay(
        completedRegion: GameRegion.forLevel(widget.level),
        newRegion: GameRegion.forLevel(nextLevel),
        startingLevel: nextLevel,
        onFinished: onFinished,
      );
    }
    return LevelTransitionOverlay(
      nextLevel: nextLevel,
      onFinished: onFinished,
    );
  }

  /// Convert a board (row,col) cell into the screen pixel center using the
  /// board rect captured by the LayoutBuilder. Falls back to screen center
  /// if the board hasn't laid out yet.
  Offset _cellCenterPx(Position cell) {
    final r = _boardRect;
    if (r == null) {
      final size = MediaQuery.of(context).size;
      return Offset(size.width / 2, size.height / 2);
    }
    final cols = _controller.config.cols;
    final rows = _controller.config.rows;
    final dx = r.left + r.width * (cell.col + 0.5) / cols;
    final dy = r.top + r.height * (cell.row + 0.5) / rows;
    return Offset(dx, dy);
  }

  void _spawnScorePopup(int delta, Position cell) {
    if (delta <= 0 || !mounted) return;
    final id = _popupSeq++;
    final pos = _cellCenterPx(cell);
    setState(() {
      _popups.add(_ScorePopupData(id: id, delta: delta, position: pos));
    });
  }

  void _removeScorePopup(int id) {
    if (!mounted) return;
    setState(() => _popups.removeWhere((p) => p.id == id));
  }

  void _triggerBigShake(double intensity) {
    if (!mounted) return;
    _bigShakeIntensity = intensity.clamp(0.2, 1.2);
    _bigShake.forward(from: 0);
  }

  // Bouncing "+3 HAMLE!" chip shown briefly when ExtraMoves booster used.
  bool _extraMovesChipVisible = false;
  void _triggerExtraMovesPop() {
    if (!mounted) return;
    setState(() => _extraMovesChipVisible = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _extraMovesChipVisible = false);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _shake.dispose();
    _bigShake.dispose();
    _comboHideTimer?.cancel();
    _skipBtnTimer?.cancel();
    super.dispose();
  }

  void _onBack() => context.go('/map');

  @override
  Widget build(BuildContext context) {
    final region = GameRegion.forLevel(widget.level);
    return Scaffold(
      backgroundColor: TT.oceanDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _GameBackground(region: region),
          // Mystical floating fireflies / glow particles drifting over BG.
          _FireflyLayer(),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    GameHud(
                      level: _controller.config.levelNumber,
                      movesLeft: _controller.movesLeft,
                      score: _controller.score,
                      timeLeft: _controller.timeLeft,
                      goals: _controller.goals,
                      onPause: _controller.togglePause,
                      onBack: _onBack,
                    ),
                    LevelObjectiveBanner(
                      goals: _controller.goals,
                      targetScore: _controller.config.targetScore,
                    ),
                    ScoreProgressBar(
                      score: _controller.score,
                      targetScore: _controller.config.targetScore,
                      stars: _controller.stars,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        child: Center(
                          child: AspectRatio(
                            // Board is 7 cols × 9 rows; aspect ratio 7/9.5
                            // (extra 0.5 for the gold frame padding).
                            aspectRatio: 7 / 9.5,
                            child: LayoutBuilder(
                              builder: (lbCtx, lbConstraints) {
                                // Capture the board area in screen coordinates so
                                // popup labels can be positioned at cell centers.
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  final box = lbCtx.findRenderObject() as RenderBox?;
                                  if (box == null || !box.hasSize) return;
                                  final origin = box.localToGlobal(Offset.zero);
                                  final newRect = origin & box.size;
                                  if (_boardRect != newRect) {
                                    setState(() => _boardRect = newRect);
                                  }
                                });
                                return AnimatedBuilder(
                                  animation: Listenable.merge([_shake, _bigShake]),
                                  builder: (context, child) {
                                    final t = _shake.value;
                                    final dx = t == 0
                                        ? 0.0
                                        : ((1 - t) * 8 * math.sin(t * 6.28 * 3) * 0.6);
                                    final bt = _bigShake.value;
                                    // Subtle nudge — peak ~5px so the board
                                    // softly bumps without screen-shaking.
                                    final amp = (1 - bt) * 5 * _bigShakeIntensity;
                                    final bdx = bt == 0
                                        ? 0.0
                                        : amp * math.sin(bt * 6.28 * 4);
                                    final bdy = bt == 0
                                        ? 0.0
                                        : amp * 0.4 * math.cos(bt * 6.28 * 5);
                                    return Transform.translate(
                                      offset: Offset(dx + bdx, bdy),
                                      child: child,
                                    );
                                  },
                                  child: RepaintBoundary(
                                    child: _IslandFrameBoard(
                                      child: GameBoard(
                                        grid: _controller.grid,
                                        selectedCell: _controller.selectedCell,
                                        hintPositions: _controller.hintPositions,
                                        boosterMode: _controller.boosterMode,
                                        onCellTapped: (pos) => _controller.onCellTapped(pos),
                                        onSwipe: (pos, dir) => _controller.onSwipeTo(pos, dir),
                                        animator: _controller.animator,
                                        onCellMetrics: _controller.setCellMetrics,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Builder(builder: (context) {
                      final progress = ref.watch(playerProgressProvider);
                      return BoosterBar(
                        boosterMode: _controller.boosterMode,
                        hammerCount: progress.hammerCount,
                        colorBlastCount: progress.colorBlastCount,
                        extraMovesCount: progress.extraMovesCount,
                        playerLevel: progress.currentLevel,
                        unlockLevel: 10,
                        onActivate: (type) => _controller.activateBooster(type),
                        onCancel: _controller.cancelBooster,
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
                if (_displayedCombo != null)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35,
                    left: 0,
                    right: 0,
                    child: Center(child: ComboText(comboCount: _displayedCombo!)),
                  ),
                if (_statusBannerText != null)
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.40,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          _statusBannerText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(1, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_skipBtnVisible)
                  Positioned(
                    bottom: 110,
                    right: 18,
                    child: _SkipButton(onTap: _onSkipPressed),
                  ),
                // Floating "+N" score popups at match centroids.
                for (final p in _popups)
                  ScorePopup(
                    key: ValueKey('popup-${p.id}'),
                    delta: p.delta,
                    start: p.position,
                    onDone: () => _removeScorePopup(p.id),
                  ),
                if (_showGreeting)
                  LevelStartGreeting(
                    onFinished: () {
                      if (mounted) setState(() => _showGreeting = false);
                    },
                  ),
                if (_controller.state == GameState.levelComplete && !_showTransition)
                  LevelCompleteOverlay(
                    score: _controller.score,
                    stars: _controller.stars,
                    coinsEarned: _controller.coinsEarned,
                    maxCombo: _controller.maxComboThisLevel,
                    onContinue: () {
                      ref.read(playerProgressProvider.notifier).completeLevel(
                            widget.level,
                            _controller.stars,
                            _controller.score,
                            _controller.coinsEarned,
                          );
                      // Show animated transition before navigating to map.
                      setState(() => _showTransition = true);
                    },
                  ),
                if (_controller.state == GameState.gameOver)
                  GameOverOverlay(
                    score: _controller.score,
                    onRetry: () => _startLevel(widget.level),
                    onQuit: _onBack,
                    showAdButton: AdManager.instance.isRewardedAdReady &&
                        !ref.read(playerProgressProvider).removeAdsPurchased,
                    onWatchAd: () {
                      AdManager.instance.showRewardedAd(
                        onRewarded: () => _controller.addExtraMoves(3),
                      );
                    },
                  ),
                if (_tutorial.shouldShowForLevel(widget.level))
                  TutorialOverlay(
                    step: _tutorial.currentStep!,
                    onContinue: () {
                      setState(() {
                        _tutorial.advance(widget.level);
                      });
                    },
                    onSkip: () {
                      setState(() {
                        _tutorial.skip(widget.level);
                      });
                    },
                  ),
                if (_controller.state == GameState.paused)
                  _PauseOverlay(
                    onResume: _controller.togglePause,
                    onRestart: () => _startLevel(widget.level),
                    onQuit: _onBack,
                  ),
              ],
            ),
          ),
          // Transition overlay sits OUTSIDE SafeArea so its background
          // covers the status bar / notch area as well — otherwise the
          // previous screen's BG would peek through at the top edge.
          if (_showTransition) Positioned.fill(child: _buildTransitionOverlay()),

          // +3 HAMLE bouncing chip — fires when ExtraMoves booster used.
          if (_extraMovesChipVisible)
            IgnorePointer(
              child: Align(
                alignment: const Alignment(0, -0.35),
                child: _ExtraMovesChip(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtraMovesChip extends StatelessWidget {
  const _ExtraMovesChip();
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (_, t, __) {
        final scale = 0.4 + 0.8 * t;
        final opacity = (1.0 - (t - 0.7).clamp(0.0, 0.3) / 0.3).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF6B0), Color(0xFFE8A317), Color(0xFF9E6A0A)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8A317).withValues(alpha: 0.7),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.skip_next_rounded, color: Color(0xFF6B0B0B), size: 32),
                  SizedBox(width: 8),
                  Text(
                    '+3 HAMLE!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B0B0B),
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(color: Color(0xFFFFE89C), blurRadius: 4),
                      ],
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

// ─── Firefly / glow particle layer — drifting yellow-gold sparkles over the
// jungle BG, mimicking the reference design's mystical atmosphere.
class _FireflyLayer extends StatefulWidget {
  const _FireflyLayer();

  @override
  State<_FireflyLayer> createState() => _FireflyLayerState();
}

class _FireflyLayerState extends State<_FireflyLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _FireflyPainter(t: _ctrl.value),
          ),
        ),
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  final double t;
  _FireflyPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(33);
    for (int i = 0; i < 18; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height;
      final phase = rng.nextDouble() * 2 * math.pi;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final r = 1.4 + rng.nextDouble() * 2.5;

      final x = bx + math.sin(t * 2 * math.pi * speed + phase) * 14;
      final y = by + math.cos(t * 2 * math.pi * speed + phase * 0.7) * 10;
      final pulse = (math.sin(t * 2 * math.pi * 1.3 + phase) + 1) / 2;
      final alpha = (60 + 140 * pulse).toInt().clamp(0, 200);

      // soft halo
      canvas.drawCircle(
        Offset(x, y),
        r * 3.2,
        Paint()
          ..color = const Color(0xFFFFE89C).withAlpha((alpha * 0.5).toInt())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // core
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = const Color(0xFFFFFAD8).withAlpha(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter old) => true;
}

// ─── Game background — DEDICATED mystical jungle wallpaper.
// Always uses the jungle BG (not region BG) to match the target reference.
class _GameBackground extends StatelessWidget {
  final GameRegion region;
  const _GameBackground({required this.region});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      TA.gameJungleBg,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Image.asset(
        region.backgroundAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          decoration: const BoxDecoration(gradient: TT.oceanDepthGradient),
        ),
      ),
    );
  }
}

// ─── Board frame — ornate gold with palm leaf corner decor (mockup match).
// Deep navy interior, subtle teal cell grid, wider gold metallic edge.
class _IslandFrameBoard extends StatelessWidget {
  final Widget child;
  const _IslandFrameBoard({required this.child});

  @override
  Widget build(BuildContext context) {
    // Compact framed board with palm leaf decor on the top corners
    // (overlaid INSIDE the AspectRatio area so they don't add to layout
    // size and don't create empty padding above/below cells).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TT.goldShine, TT.gold, TT.goldDeep],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(200), blurRadius: 18, offset: const Offset(0, 6)),
              BoxShadow(color: TT.gold.withAlpha(140), blurRadius: 22, spreadRadius: -2),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Color(0xFF0F3A52),
                  Color(0xFF052035),
                  Color(0xFF02101C),
                ],
                stops: [0.0, 0.65, 1.0],
              ),
              border: Border.all(color: TT.goldShine.withAlpha(160), width: 1),
            ),
            padding: const EdgeInsets.all(4),
            child: child,
          ),
        ),
        // Top-left palm leaf decor — sits OVER the gold frame top corner.
        Positioned(
          top: -10,
          left: -8,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.45,
              child: Image.asset(
                TA.decorPalmLeaves,
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        // Top-right palm leaf decor (mirrored)
        Positioned(
          top: -10,
          right: -8,
          child: IgnorePointer(
            child: Transform(
              transform: Matrix4.identity()
                ..rotateY(3.14159)
                ..rotateZ(0.45),
              alignment: Alignment.center,
              child: Image.asset(
                TA.decorPalmLeaves,
                width: 56,
                height: 56,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pause overlay ────────────────────────────────────────────────────────
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(190),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: IslandPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DURAKLADI',
                  style: TT.displayMedium.copyWith(color: TT.goldDeep, letterSpacing: 2),
                ),
                const SizedBox(height: 22),
                IslandButton(
                  text: 'Devam Et',
                  color: IslandButtonColor.palm,
                  size: IslandButtonSize.medium,
                  fullWidth: true,
                  icon: Icons.play_arrow_rounded,
                  onPressed: onResume,
                ),
                const SizedBox(height: 10),
                IslandButton(
                  text: 'Baştan Başla',
                  color: IslandButtonColor.lagoon,
                  size: IslandButtonSize.medium,
                  fullWidth: true,
                  icon: Icons.refresh_rounded,
                  onPressed: onRestart,
                ),
                const SizedBox(height: 10),
                IslandButton(
                  text: 'Çık',
                  color: IslandButtonColor.coral,
                  size: IslandButtonSize.medium,
                  fullWidth: true,
                  icon: Icons.exit_to_app_rounded,
                  onPressed: onQuit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight bookkeeping for a single in-flight score popup. The
/// ScorePopup widget owns its own animation; we just need to know which
/// instance to prune when it finishes.
class _ScorePopupData {
  final int id;
  final int delta;
  final Offset position;
  const _ScorePopupData({required this.id, required this.delta, required this.position});
}

// ─── Atla (skip) button — surfaces during long auto-cascades to let the
// player fast-forward animation. Pulsates softly to draw attention.
class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final scale = 0.96 + 0.06 * t;
        final glowAlpha = (140 + 80 * t).toInt();
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [TT.goldShine, TT.goldBright, TT.gold, TT.goldDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: TT.gold.withAlpha(glowAlpha),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(180),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fast_forward_rounded,
                    color: TT.driftWoodDark,
                    size: 20,
                    shadows: [
                      Shadow(color: Colors.white.withAlpha(160), blurRadius: 1, offset: const Offset(0, 1)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ATLA',
                    style: TextStyle(
                      color: TT.driftWoodDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                      shadows: [
                        Shadow(color: Colors.white.withAlpha(180), blurRadius: 1, offset: const Offset(0, 1)),
                      ],
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


import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:patpat_game/game/board_animator.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/game_grid.dart';
import 'package:patpat_game/models/position.dart';
import 'package:patpat_game/theme/game_colors.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/special_effects_overlay.dart';

/// Sprite asset path for a [JellyType].
String _jellySpritePath(JellyType type) {
  switch (type) {
    case JellyType.purple:
      return 'assets/sprites/jelly_purple.png';
    case JellyType.yellow:
      return 'assets/sprites/jelly_yellow.png';
    case JellyType.blue:
      return 'assets/sprites/jelly_blue.png';
    case JellyType.green:
      return 'assets/sprites/jelly_green.png';
    case JellyType.pink:
      return 'assets/sprites/jelly_pink.png';
    case JellyType.orange:
      return 'assets/sprites/jelly_orange.png';
    case JellyType.black:
      return 'assets/sprites/jelly_black.png';
  }
}

/// Interactive game board rendered as a grid of sprite-based widgets.
///
/// Handles tap and swipe gestures. Each cell renders jelly sprites from
/// `assets/sprites/`, with overlays for specials, obstacles, selection,
/// and hints. Supports smooth Candy Crush-style animations via
/// [BoardAnimator] for swaps, destroys, gravity, and fills.
class GameBoard extends StatefulWidget {
  final GameGrid grid;
  final Position? selectedCell;
  final (Position, Position)? hintPositions;
  final ActiveBoosterMode boosterMode;
  final Function(Position) onCellTapped;
  final Function(Position, SwapDirection) onSwipe;
  final BoardAnimator animator;
  final Function(double cellSize, double gap)? onCellMetrics;

  const GameBoard({
    super.key,
    required this.grid,
    this.selectedCell,
    this.hintPositions,
    this.boosterMode = ActiveBoosterMode.none,
    required this.onCellTapped,
    required this.onSwipe,
    required this.animator,
    this.onCellMetrics,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Ticker _animTicker;
  bool _tickerActive = false;

  Offset? _panStart;
  Position? _panStartCell;
  bool _swipeHandled = false;
  double _lastCellSize = 0;

  static const double _gap = 3.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Ticker for smooth 60fps animation rendering
    _animTicker = createTicker(_onAnimTick);
    widget.animator.addListener(_onAnimatorChanged);
  }

  void _onAnimatorChanged() {
    if (widget.animator.hasActiveAnimations && !_tickerActive) {
      _tickerActive = true;
      _animTicker.start();
    } else if (!widget.animator.hasActiveAnimations && _tickerActive) {
      _tickerActive = false;
      _animTicker.stop();
      if (mounted) setState(() {});
    }
  }

  void _onAnimTick(Duration elapsed) {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animator != widget.animator) {
      oldWidget.animator.removeListener(_onAnimatorChanged);
      widget.animator.addListener(_onAnimatorChanged);
    }
  }

  @override
  void dispose() {
    widget.animator.removeListener(_onAnimatorChanged);
    if (_tickerActive) _animTicker.stop();
    _animTicker.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Compute cell size to fit the grid in the given [constraints].
  double _cellSize(BoxConstraints constraints) {
    final maxW =
        (constraints.maxWidth - _gap * (widget.grid.cols - 1)) /
        widget.grid.cols;
    final maxH =
        (constraints.maxHeight - _gap * (widget.grid.rows - 1)) /
        widget.grid.rows;
    return min(maxW, maxH).clamp(30.0, 52.0);
  }

  /// Board total width/height.
  double _boardWidth(double cellSize) =>
      cellSize * widget.grid.cols + _gap * (widget.grid.cols - 1);

  double _boardHeight(double cellSize) =>
      cellSize * widget.grid.rows + _gap * (widget.grid.rows - 1);

  /// Hit-test: find the cell under [local] coordinates.
  Position? _hitTest(Offset local, double cellSize, Offset boardOffset) {
    final dx = local.dx - boardOffset.dx;
    final dy = local.dy - boardOffset.dy;
    if (dx < 0 || dy < 0) return null;

    final col = (dx / (cellSize + _gap)).floor();
    final row = (dy / (cellSize + _gap)).floor();
    if (col < 0 ||
        col >= widget.grid.cols ||
        row < 0 ||
        row >= widget.grid.rows) {
      return null;
    }
    return Position(row, col);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = _cellSize(constraints);
        final bw = _boardWidth(cellSize);
        final bh = _boardHeight(cellSize);
        final boardOffset = Offset(
          (constraints.maxWidth - bw) / 2,
          (constraints.maxHeight - bh) / 2,
        );

        // Report cell metrics to controller for animation calculations
        if (cellSize != _lastCellSize) {
          _lastCellSize = cellSize;
          widget.onCellMetrics?.call(cellSize, _gap);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            _panStart = details.localPosition;
            _panStartCell = _hitTest(
              details.localPosition,
              cellSize,
              boardOffset,
            );
            _swipeHandled = false;
          },
          onPanUpdate: (details) {
            if (_swipeHandled || _panStart == null || _panStartCell == null) {
              return;
            }
            final delta = details.localPosition - _panStart!;
            final threshold = cellSize * 0.3;
            if (delta.distance < threshold) return;

            SwapDirection dir;
            if (delta.dx.abs() > delta.dy.abs()) {
              dir = delta.dx > 0 ? SwapDirection.right : SwapDirection.left;
            } else {
              dir = delta.dy > 0 ? SwapDirection.down : SwapDirection.up;
            }

            _swipeHandled = true;
            widget.onSwipe(_panStartCell!, dir);
          },
          onPanEnd: (_) {
            if (!_swipeHandled && _panStartCell != null) {
              widget.onCellTapped(_panStartCell!);
            }
            _panStart = null;
            _panStartCell = null;
          },
          child: RepaintBoundary(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulseValue = _pulseController.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Position each cell individually for precise layout
                      for (int r = 0; r < widget.grid.rows; r++)
                        for (int c = 0; c < widget.grid.cols; c++)
                          _buildAnimatedCell(
                            r, c, cellSize, boardOffset, pulseValue,
                          ),
                      // Special activation effects overlay (laser, shockwave, etc.)
                      if (widget.animator.activeSpecialEffect != null)
                        Positioned.fill(
                          child: SpecialEffectsOverlay(
                            activeEffect: widget.animator.activeSpecialEffect!,
                            cellSize: cellSize,
                            gap: _gap,
                            gridRows: widget.grid.rows,
                            gridCols: widget.grid.cols,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build a single cell with animation offsets, scale, and opacity applied.
  Widget _buildAnimatedCell(
    int r,
    int c,
    double cellSize,
    Offset boardOffset,
    double pulseValue,
  ) {
    final anim = widget.animator.getAnimation(r, c);
    final baseLeft = boardOffset.dx + c * (cellSize + _gap);
    final baseTop = boardOffset.dy + r * (cellSize + _gap);

    final offset = anim?.currentOffset ?? Offset.zero;
    final scale = anim?.currentScale ?? 1.0;
    final opacity = anim?.currentOpacity ?? 1.0;

    final cellData = widget.grid.get(r, c);
    final JellyType? jellyType = cellData.jellyType;

    Widget cell = _JellyCell(
      cell: cellData,
      cellSize: cellSize,
      isSelected: widget.selectedCell != null &&
          widget.selectedCell!.row == r &&
          widget.selectedCell!.col == c,
      isHint: widget.hintPositions != null &&
          ((widget.hintPositions!.$1.row == r &&
                  widget.hintPositions!.$1.col == c) ||
              (widget.hintPositions!.$2.row == r &&
                  widget.hintPositions!.$2.col == c)),
      pulseValue: pulseValue,
    );

    if (anim != null) {
      if (scale != 1.0 || opacity != 1.0) {
        cell = Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 1.5),
            child: cell,
          ),
        );
      }
    }

    // Swap dust trail — small particles falling behind a tile sliding
    // sideways via animateSwap. We distinguish swap from fall by checking
    // that the non-zero displacement lives in offsetEnd (swap) rather
    // than offsetStart (fall).
    if (anim != null &&
        anim.type == AnimType.move &&
        anim.offsetEnd != Offset.zero &&
        jellyType != null) {
      cell = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -cellSize * 0.5,
            top: -cellSize * 0.5,
            width: cellSize * 2,
            height: cellSize * 2,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SwapDustPainter(
                  jellyType: jellyType,
                  progress: anim.curvedProgress,
                  travel: anim.offsetEnd,
                  cellSize: cellSize,
                ),
              ),
            ),
          ),
          cell,
        ],
      );
    }

    // Tropical destroy particles — colored burst per product type when matched.
    final isDestroying = anim?.type == AnimType.destroy;
    if (isDestroying && jellyType != null) {
      cell = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -cellSize * 0.3,
            top: -cellSize * 0.3,
            width: cellSize * 1.6,
            height: cellSize * 1.6,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TropicalBurstPainter(
                  jellyType: jellyType,
                  progress: anim!.curvedProgress,
                ),
              ),
            ),
          ),
          cell,
        ],
      );
    }

    // Pre-match golden glow — fires for ~120ms BEFORE destroy so the player
    // sees what's about to pop. Brightens, scales up to 1.08, then hands off.
    final isFlashing = anim?.type == AnimType.flash;
    if (isFlashing && jellyType != null) {
      final t = anim!.curvedProgress;
      final scale = 1.0 + 0.08 * (1 - (1 - t) * (1 - t));
      cell = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -cellSize * 0.25,
            top: -cellSize * 0.25,
            width: cellSize * 1.5,
            height: cellSize * 1.5,
            child: IgnorePointer(
              child: CustomPaint(painter: _PreMatchGlowPainter(progress: t)),
            ),
          ),
          Transform.scale(scale: scale, child: cell),
        ],
      );
    }

    // Special spawn — dramatic rainbow ring + shockwave + sparkles.
    final isSpecialSpawning = anim?.type == AnimType.specialSpawn;
    if (isSpecialSpawning) {
      cell = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -cellSize * 0.6,
            top: -cellSize * 0.6,
            width: cellSize * 2.2,
            height: cellSize * 2.2,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpecialSpawnPainter(progress: anim!.curvedProgress),
              ),
            ),
          ),
          cell,
        ],
      );
    }

    return Positioned(
      left: baseLeft + offset.dx,
      top: baseTop + offset.dy,
      width: cellSize,
      height: cellSize,
      child: cell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JellyCell — individual cell widget with sprite rendering
// ─────────────────────────────────────────────────────────────────────────────

class _JellyCell extends StatelessWidget {
  final dynamic cell; // Cell type
  final double cellSize;
  final bool isSelected;
  final bool isHint;
  final double pulseValue;

  const _JellyCell({
    required this.cell,
    required this.cellSize,
    required this.isSelected,
    required this.isHint,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    final obstacleType = cell.obstacle as ObstacleType;
    final jellyType = cell.jellyType as JellyType?;
    final specialType = cell.specialType as SpecialType;
    final hasJelly = cell.hasJelly as bool;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Luxury glassmorphic tile slot with inner bevel depth
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x35FFFFFF),
                  Color(0x12FFFFFF),
                  Color(0x04000000),
                ],
              ),
              border: Border.all(color: Colors.white.withAlpha(45), width: 0.8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                  spreadRadius: -0.5,
                ),
              ],
            ),
          ),
        ),

        // 2. Obstacle underlay (ice, portal, etc.)
        if (obstacleType == ObstacleType.ice1 ||
            obstacleType == ObstacleType.ice2 ||
            obstacleType == ObstacleType.portal)
          Positioned.fill(
            child: _ObstacleOverlay(
              obstacle: obstacleType,
              cellSize: cellSize,
            ),
          ),

        // 3. Jelly content — specials get entirely unique widgets
        if (hasJelly && jellyType != null)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(cellSize * 0.04),
              child: _buildJellyContent(
                  jellyType, specialType, cellSize, pulseValue),
            ),
          ),

        // 3b. Obstacle overlay (chains, fog, honey, box, chocolate, iceWall)
        if (obstacleType != ObstacleType.none &&
            obstacleType != ObstacleType.ice1 &&
            obstacleType != ObstacleType.ice2 &&
            obstacleType != ObstacleType.portal)
          Positioned.fill(
            child: _ObstacleOverlay(
              obstacle: obstacleType,
              cellSize: cellSize,
            ),
          ),

        // 4. Selection highlight
        if (isSelected)
          Positioned.fill(
            child: _SelectionHighlight(
              pulseValue: pulseValue,
              cellSize: cellSize,
            ),
          ),

        // 5. Hint highlight
        if (isHint)
          Positioned.fill(
            child: _HintHighlight(
              pulseValue: pulseValue,
            ),
          ),
      ],
    );
  }

  /// Route to the correct visual widget based on special type.
  static Widget _buildJellyContent(
    JellyType type,
    SpecialType special,
    double cellSize,
    double pulseValue,
  ) {
    switch (special) {
      case SpecialType.none:
        return _GlossyCandyJelly(type: type, cellSize: cellSize);
      case SpecialType.rocketHorizontal:
        return _RocketJelly(
            type: type, horizontal: true, pulseValue: pulseValue);
      case SpecialType.rocketVertical:
        return _RocketJelly(
            type: type, horizontal: false, pulseValue: pulseValue);
      case SpecialType.bomb:
        return _BombJelly(pulseValue: pulseValue, cellSize: cellSize);
      case SpecialType.rainbow:
        return _RainbowJelly(pulseValue: pulseValue, cellSize: cellSize);
      case SpecialType.lightning:
        return _LightningJelly(
            type: type, pulseValue: pulseValue, cellSize: cellSize);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlossyCandyJelly — ultra-vibrant candy with 3D specular gloss & shadow
// ─────────────────────────────────────────────────────────────────────────────

class _GlossyCandyJelly extends StatelessWidget {
  final JellyType type;
  final double cellSize;

  const _GlossyCandyJelly({
    required this.type,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. Soft ambient colored drop shadow beneath the candy
        Positioned(
          bottom: cellSize * 0.04,
          child: Container(
            width: cellSize * 0.70,
            height: cellSize * 0.20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cellSize * 0.2),
              boxShadow: [
                BoxShadow(
                  color: type.color.withAlpha(110),
                  blurRadius: 7,
                  spreadRadius: 1.5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        // 2. High-res candy jelly sprite
        Image.asset(
          _jellySpritePath(type),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _FallbackJelly(type: type),
        ),
        // 3. 3D Specular gloss shine band on top-left quadrant
        Positioned(
          top: cellSize * 0.08,
          left: cellSize * 0.12,
          child: Container(
            width: cellSize * 0.26,
            height: cellSize * 0.16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cellSize * 0.12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(170),
                  Colors.white.withAlpha(70),
                  Colors.white.withAlpha(0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FallbackJelly — colored circle fallback if sprite fails to load
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackJelly extends StatelessWidget {
  final JellyType type;
  const _FallbackJelly({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          radius: 0.9,
          colors: [
            Color.lerp(type.color, Colors.white, 0.3)!,
            type.color,
            Color.lerp(type.color, Colors.black, 0.3)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: type.color.withAlpha(80),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RocketJelly — unique visual for horizontal/vertical rocket specials
// ─────────────────────────────────────────────────────────────────────────────

class _RocketJelly extends StatelessWidget {
  final JellyType type;
  final bool horizontal;
  final double pulseValue;

  const _RocketJelly({
    required this.type,
    required this.horizontal,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Outer pulsing glow halo behind the whole rocket — wider so
        // the rocket "leaks" past its tile boundaries.
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: TT.coral.withAlpha((100 + pulseValue * 70).toInt()),
                  blurRadius: 20 + pulseValue * 10,
                  spreadRadius: 2 + pulseValue * 3,
                ),
                BoxShadow(
                  color: TT.gold.withAlpha((90 + pulseValue * 50).toInt()),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // 2. The rocket capsule itself — silhouette with nose cone, body,
        // tail fins, and an animated exhaust flame.
        Positioned.fill(
          child: CustomPaint(
            painter: _RocketCapsulePainter(
              horizontal: horizontal,
              pulseValue: pulseValue,
              jellyColor: type.color,
            ),
          ),
        ),
        // 3. The bird's head peeking from a small cockpit window in the
        // upper part of the capsule. We center & shrink the sprite so it
        // reads as a passenger, not the whole tile.
        Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 0.50,
            heightFactor: 0.50,
            alignment: horizontal
                ? const Alignment(-0.10, -0.05)
                : const Alignment(0.0, -0.32),
            child: Image.asset(
              _jellySpritePath(type),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        // 4. Direction chevrons — bright animated arrows pointing the
        // way the rocket will fire.
        Positioned.fill(
          child: CustomPaint(
            painter: _RocketArrowPainter(
              horizontal: horizontal,
              pulseValue: pulseValue,
              color: type.color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a chibi rocket capsule that fills the cell:
///   • Nose cone (gold tipped)
///   • Body (gold/sand with the jelly's accent stripe)
///   • Tail fins
///   • Animated flame at the exhaust end
class _RocketCapsulePainter extends CustomPainter {
  final bool horizontal;
  final double pulseValue;
  final Color jellyColor;

  _RocketCapsulePainter({
    required this.horizontal,
    required this.pulseValue,
    required this.jellyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    // Orient the rocket — vertical version is the natural form. For
    // horizontal rockets we rotate the canvas 90° so the same shapes
    // are reused.
    canvas.translate(w / 2, h / 2);
    if (horizontal) canvas.rotate(-pi / 2);
    canvas.translate(-w / 2, -h / 2);

    // Drop shadow under the body.
    final shadow = Paint()
      ..color = Colors.black.withAlpha(120)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // ─── Body: rounded rectangle ───
    final bodyRect = Rect.fromLTWH(w * 0.30, h * 0.18, w * 0.40, h * 0.55);
    final bodyR = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.16));
    canvas.drawRRect(bodyR.shift(const Offset(0, 2.5)), shadow);
    canvas.drawRRect(
      bodyR,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TT.goldShine, TT.gold, TT.goldDeep],
        ).createShader(bodyRect),
    );
    // Color stripe — visible "racing band" derived from the jelly color.
    final stripeRect = Rect.fromLTWH(w * 0.30, h * 0.50, w * 0.40, h * 0.10);
    canvas.drawRect(
      stripeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(jellyColor, Colors.white, 0.35)!,
            jellyColor,
          ],
        ).createShader(stripeRect),
    );
    // Body outline.
    canvas.drawRRect(
      bodyR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TT.goldDeep,
    );

    // ─── Cockpit window (where the bird peeks out) ───
    final windowCenter = Offset(w * 0.50, h * 0.32);
    final windowR = w * 0.13;
    canvas.drawCircle(
      windowCenter,
      windowR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFF8FCFFF), Color(0xFF1F77BF)],
        ).createShader(Rect.fromCircle(center: windowCenter, radius: windowR)),
    );
    canvas.drawCircle(
      windowCenter,
      windowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TT.goldDeep,
    );

    // ─── Nose cone (top) ───
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.05)
      ..lineTo(w * 0.71, h * 0.20)
      ..lineTo(w * 0.29, h * 0.20)
      ..close();
    canvas.drawPath(nosePath.shift(const Offset(0, 2.5)), shadow);
    canvas.drawPath(
      nosePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TT.coralLight, TT.coral, TT.coralDark],
        ).createShader(Rect.fromLTWH(w * 0.29, h * 0.05, w * 0.42, h * 0.16)),
    );
    canvas.drawPath(
      nosePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TT.coralDark,
    );

    // ─── Tail fins (left + right) ───
    final finL = Path()
      ..moveTo(w * 0.30, h * 0.65)
      ..lineTo(w * 0.10, h * 0.85)
      ..lineTo(w * 0.30, h * 0.85)
      ..close();
    final finR = Path()
      ..moveTo(w * 0.70, h * 0.65)
      ..lineTo(w * 0.90, h * 0.85)
      ..lineTo(w * 0.70, h * 0.85)
      ..close();
    final finPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [TT.coral, TT.coralDark],
      ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.20));
    canvas.drawPath(finL.shift(const Offset(0, 2.5)), shadow);
    canvas.drawPath(finR.shift(const Offset(0, 2.5)), shadow);
    canvas.drawPath(finL, finPaint);
    canvas.drawPath(finR, finPaint);

    // ─── Animated flame at exhaust ───
    final flameTopY = h * 0.78;
    final flameAmp = 1.0 + pulseValue * 0.6;
    final flameH = h * 0.20 * flameAmp;
    final flameCenter = Offset(w * 0.50, flameTopY + flameH / 2);

    // Outer orange.
    final outerFlame = Path()
      ..moveTo(w * 0.34, flameTopY)
      ..quadraticBezierTo(w * 0.30, flameTopY + flameH * 0.45,
          w * 0.50, flameTopY + flameH)
      ..quadraticBezierTo(w * 0.70, flameTopY + flameH * 0.45,
          w * 0.66, flameTopY)
      ..close();
    canvas.drawPath(
      outerFlame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD13B), Color(0xFFFF6E1A), Color(0xFFE83A1A)],
        ).createShader(Rect.fromCircle(center: flameCenter, radius: flameH))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    // Inner white-yellow core.
    final innerFlame = Path()
      ..moveTo(w * 0.42, flameTopY)
      ..quadraticBezierTo(w * 0.40, flameTopY + flameH * 0.35,
          w * 0.50, flameTopY + flameH * 0.85)
      ..quadraticBezierTo(w * 0.60, flameTopY + flameH * 0.35,
          w * 0.58, flameTopY)
      ..close();
    canvas.drawPath(
      innerFlame,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFFFFE89C)],
        ).createShader(Rect.fromCircle(center: flameCenter, radius: flameH * 0.5)),
    );

    // Tiny spark dots scattering below the flame.
    final sparkPaint = Paint()
      ..color = const Color(0xFFFFD13B).withAlpha((150 + pulseValue * 80).toInt());
    for (int i = 0; i < 4; i++) {
      final sx = w * 0.36 + (i * w * 0.085) + pulseValue * 4;
      final sy = flameTopY + flameH + 2 + (i.isEven ? 1 : 4);
      canvas.drawCircle(Offset(sx, sy), 1.6, sparkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RocketCapsulePainter old) =>
      old.pulseValue != pulseValue ||
      old.horizontal != horizontal ||
      old.jellyColor != jellyColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// _BombJelly — unique visual for bomb specials
// ─────────────────────────────────────────────────────────────────────────────

class _BombJelly extends StatelessWidget {
  final double pulseValue;
  final double cellSize;

  const _BombJelly({
    required this.pulseValue,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final rotationAngle = pulseValue * 2 * pi;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Pulsing orange glow background
        Positioned.fill(
          child: Transform.scale(
            scale: 1.0 + pulseValue * 0.1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722)
                        .withAlpha((70 + pulseValue * 70).toInt()),
                    blurRadius: 12 + pulseValue * 8,
                    spreadRadius: 1 + pulseValue * 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        // 2. Bomb sprite
        Positioned.fill(
          child: Transform.scale(
            scale: 1.0 + pulseValue * 0.08,
            child: Image.asset(
              'assets/sprites/jelly_bomb.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) =>
                  const _FallbackJelly(type: JellyType.orange),
            ),
          ),
        ),
        // 3. Rotating ring of 4 spark dots
        ...List.generate(4, (i) {
          final angle = rotationAngle + i * pi / 2;
          final radius = cellSize * 0.38;
          final cx = cellSize / 2 + cos(angle) * radius;
          final cy = cellSize / 2 + sin(angle) * radius;
          final sparkAlpha = (180 + pulseValue * 75).toInt().clamp(0, 255);
          return Positioned(
            left: cx - 3,
            top: cy - 3,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFAB40).withAlpha(sparkAlpha),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6D00)
                        .withAlpha((sparkAlpha * 0.7).toInt()),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RainbowJelly — unique visual for rainbow specials
// ─────────────────────────────────────────────────────────────────────────────

class _RainbowJelly extends StatelessWidget {
  final double pulseValue;
  final double cellSize;

  const _RainbowJelly({
    required this.pulseValue,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final orbitAngle = pulseValue * 2 * pi;
    final radius = cellSize * 0.40;
    final center = cellSize / 2;
    const rainbowColors = [
      Color(0xFFFF4D80), // pink
      Color(0xFFFF801A), // orange
      Color(0xFFFFD91A), // yellow
      Color(0xFF33D973), // green
      Color(0xFF338CFF), // blue
      Color(0xFF8B24DB), // purple
    ];

    // Hue-shifting glow color cycles through full spectrum.
    final hue = pulseValue * 360;
    final glowColor = HSLColor.fromAHSL(1, hue, 0.95, 0.65).toColor();
    // Subtle "breathe" — overall tile pulses 1.0 → 1.06 so it stands out
    // amongst static tiles even at a glance.
    final breathScale = 1.0 + 0.06 * sin(pulseValue * 2 * pi);

    return Transform.scale(
      scale: breathScale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Big radiant rainbow halo behind the tile — bigger than the
          // cell so the rainbow special "leaks" beyond its borders.
          Positioned(
            left: -cellSize * 0.18,
            top: -cellSize * 0.18,
            width: cellSize * 1.36,
            height: cellSize * 1.36,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RainbowHaloPainter(progress: pulseValue),
              ),
            ),
          ),
          // 2. Rotating starburst rays behind the sprite.
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.rotate(
                angle: orbitAngle * 0.5,
                child: CustomPaint(
                  painter: _RainbowRaysPainter(progress: pulseValue),
                ),
              ),
            ),
          ),
          // 3. Cycling color glow box-shadow on the tile itself.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withAlpha((140 + pulseValue * 60).toInt()),
                    blurRadius: 22 + pulseValue * 10,
                    spreadRadius: 2 + pulseValue * 3,
                  ),
                ],
              ),
            ),
          ),
          // 4. Rainbow sprite (the actual tile graphic).
          Positioned.fill(
            child: Image.asset(
              'assets/sprites/jelly_rainbow.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) =>
                  const _FallbackJelly(type: JellyType.purple),
            ),
          ),
          // 5. 6 orbiting colored dots — bigger + brighter than before.
          ...List.generate(6, (i) {
            final angle = orbitAngle + i * (pi / 3);
            final dx = center + cos(angle) * radius;
            final dy = center + sin(angle) * radius;
            final dotAlpha = (220 + pulseValue * 35).toInt().clamp(0, 255);
            return Positioned(
              left: dx - 5,
              top: dy - 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withAlpha(dotAlpha),
                      rainbowColors[i].withAlpha(dotAlpha),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rainbowColors[i].withAlpha((dotAlpha * 0.7).toInt()),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          }),
          // 6. Five-pointed white "★" sparkle marker — the universal
          // 5-match badge (Candy Crush color bomb cue) that makes this
          // tile instantly readable as the BIG one.
          Positioned(
            left: center - 8,
            top: center - 8,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _FivePointStarPainter(
                  alpha: (180 + pulseValue * 75).toInt().clamp(0, 255),
                ),
              ),
            ),
          ),
          // 7. Shimmer overlay sweeps over everything.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _ShimmerPainter(pulseValue: pulseValue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outer rainbow halo — soft radial gradient that cycles through the spectrum.
class _RainbowHaloPainter extends CustomPainter {
  final double progress;
  _RainbowHaloPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final hue = progress * 360;
    final base = HSLColor.fromAHSL(1, hue, 0.9, 0.6).toColor();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            base.withAlpha(160),
            base.withAlpha(60),
            Colors.transparent,
          ],
          stops: const [0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _RainbowHaloPainter old) => old.progress != progress;
}

/// 8-point starburst rays behind the rainbow sprite — gives it a "heroic"
/// readable silhouette so the 5-match BIG one is impossible to miss.
class _RainbowRaysPainter extends CustomPainter {
  final double progress;
  _RainbowRaysPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final hue = progress * 360;
    const rayCount = 8;
    for (int i = 0; i < rayCount; i++) {
      final angle = i * (2 * pi / rayCount);
      final color = HSLColor.fromAHSL(1, (hue + i * 45) % 360, 0.95, 0.6).toColor();
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha(120), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, maxR * 1.2, 30));
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(angle - 0.06) * maxR, c.dy + sin(angle - 0.06) * maxR)
        ..lineTo(c.dx + cos(angle + 0.06) * maxR, c.dy + sin(angle + 0.06) * maxR)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainbowRaysPainter old) => old.progress != progress;
}

/// Tiny 5-pointed star painted over the center of the rainbow sprite —
/// universal "color bomb" cue.
class _FivePointStarPainter extends CustomPainter {
  final int alpha;
  _FivePointStarPainter({required this.alpha});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final outerR = r * 0.95;
    final innerR = r * 0.4;
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final radius = i.isEven ? outerR : innerR;
      final angle = -pi / 2 + i * pi / 5;
      final x = c.dx + cos(angle) * radius;
      final y = c.dy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Soft outer glow.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Crisp white star.
    canvas.drawPath(path, Paint()..color = Colors.white.withAlpha(alpha));
    // Thin gold outline.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFE8A317).withAlpha(alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _FivePointStarPainter old) => old.alpha != alpha;
}

// ─────────────────────────────────────────────────────────────────────────────
// _LightningJelly — unique visual for lightning specials
// ─────────────────────────────────────────────────────────────────────────────

class _LightningJelly extends StatelessWidget {
  final JellyType type;
  final double pulseValue;
  final double cellSize;

  const _LightningJelly({
    required this.type,
    required this.pulseValue,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final boltAlpha = (160 + pulseValue * 95).toInt().clamp(0, 255);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Electric yellow glow background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700)
                      .withAlpha((70 + pulseValue * 80).toInt()),
                  blurRadius: 10 + pulseValue * 10,
                  spreadRadius: 1 + pulseValue * 2,
                ),
              ],
            ),
          ),
        ),
        // 2. Dark sphere base with lightning bolts (CustomPainter)
        Positioned.fill(
          child: CustomPaint(
            painter: _LightningBoltPainter(
              pulseValue: pulseValue,
              baseColor: type.color,
            ),
          ),
        ),
        // 3. Central lightning bolt icon
        Center(
          child: Icon(
            Icons.flash_on,
            size: cellSize * 0.45,
            color: GameColors.goldFrameMid.withAlpha(boltAlpha),
            shadows: [
              Shadow(
                color: const Color(0xFFFFD700).withAlpha(boltAlpha),
                blurRadius: 12,
              ),
              Shadow(
                color: Colors.white.withAlpha((boltAlpha * 0.6).toInt()),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        // 4. Spark particles at pseudo-random positions
        ...List.generate(5, (i) {
          final seed = (pulseValue * 5 + i * 1.3) % 1.0;
          final sx = cellSize * (0.1 + seed * 0.8);
          final sy = cellSize * (0.1 + ((seed * 3.7) % 1.0) * 0.8);
          final dotAlpha =
              ((100 + pulseValue * 100) * (0.5 + seed * 0.5))
                  .toInt()
                  .clamp(0, 255);
          return Positioned(
            left: sx - 2,
            top: sy - 2,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(dotAlpha),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withAlpha(dotAlpha),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RocketArrowPainter — glowing arrow lines through center for rocket specials
// ─────────────────────────────────────────────────────────────────────────────

class _RocketArrowPainter extends CustomPainter {
  final bool horizontal;
  final double pulseValue;
  final Color color;

  _RocketArrowPainter({
    required this.horizontal,
    required this.pulseValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final glowAlpha = (120 + pulseValue * 120).toInt().clamp(0, 255);

    // Arrow head paint
    final arrowPaint = Paint()
      ..color = Colors.white.withAlpha(glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + pulseValue * 0.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Core line paint (brighter)
    final linePaint = Paint()
      ..color = color.withAlpha(glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 + pulseValue
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    if (horizontal) {
      // Horizontal line through center
      final lineY = center.dy;
      canvas.drawLine(
        Offset(size.width * 0.08, lineY),
        Offset(size.width * 0.92, lineY),
        linePaint,
      );
      // Left arrow head <
      final leftTip = Offset(size.width * 0.08, lineY);
      canvas.drawLine(leftTip, Offset(size.width * 0.22, lineY - size.height * 0.15), arrowPaint);
      canvas.drawLine(leftTip, Offset(size.width * 0.22, lineY + size.height * 0.15), arrowPaint);
      // Right arrow head >
      final rightTip = Offset(size.width * 0.92, lineY);
      canvas.drawLine(rightTip, Offset(size.width * 0.78, lineY - size.height * 0.15), arrowPaint);
      canvas.drawLine(rightTip, Offset(size.width * 0.78, lineY + size.height * 0.15), arrowPaint);
    } else {
      // Vertical line through center
      final lineX = center.dx;
      canvas.drawLine(
        Offset(lineX, size.height * 0.08),
        Offset(lineX, size.height * 0.92),
        linePaint,
      );
      // Top arrow head ^
      final topTip = Offset(lineX, size.height * 0.08);
      canvas.drawLine(topTip, Offset(lineX - size.width * 0.15, size.height * 0.22), arrowPaint);
      canvas.drawLine(topTip, Offset(lineX + size.width * 0.15, size.height * 0.22), arrowPaint);
      // Bottom arrow head v
      final bottomTip = Offset(lineX, size.height * 0.92);
      canvas.drawLine(bottomTip, Offset(lineX - size.width * 0.15, size.height * 0.78), arrowPaint);
      canvas.drawLine(bottomTip, Offset(lineX + size.width * 0.15, size.height * 0.78), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RocketArrowPainter old) =>
      old.pulseValue != pulseValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// _LightningBoltPainter — dark sphere with radiating electric bolts
// ─────────────────────────────────────────────────────────────────────────────

class _LightningBoltPainter extends CustomPainter {
  final double pulseValue;
  final Color baseColor;

  _LightningBoltPainter({
    required this.pulseValue,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Dark sphere base
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.9,
        colors: [
          Color.lerp(baseColor, Colors.black, 0.5)!,
          Color.lerp(baseColor, Colors.black, 0.8)!,
          Colors.black,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, spherePaint);

    // Radiating lightning bolts (4 directions)
    final boltPaint = Paint()
      ..color = const Color(0xFFFFD700).withAlpha(
          (140 + pulseValue * 100).toInt().clamp(0, 255))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    for (int i = 0; i < 4; i++) {
      final baseAngle = i * pi / 2 + pulseValue * 0.3;
      final boltStart = Offset(
        center.dx + cos(baseAngle) * radius * 0.5,
        center.dy + sin(baseAngle) * radius * 0.5,
      );
      // Zig-zag bolt
      final mid1 = Offset(
        center.dx + cos(baseAngle + 0.3) * radius * 0.8,
        center.dy + sin(baseAngle + 0.3) * radius * 0.8,
      );
      final mid2 = Offset(
        center.dx + cos(baseAngle - 0.2) * radius * 1.1,
        center.dy + sin(baseAngle - 0.2) * radius * 1.1,
      );
      final boltEnd = Offset(
        center.dx + cos(baseAngle + 0.1) * radius * 1.4,
        center.dy + sin(baseAngle + 0.1) * radius * 1.4,
      );

      final path = Path()
        ..moveTo(boltStart.dx, boltStart.dy)
        ..lineTo(mid1.dx, mid1.dy)
        ..lineTo(mid2.dx, mid2.dy)
        ..lineTo(boltEnd.dx, boltEnd.dy);
      canvas.drawPath(path, boltPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightningBoltPainter old) =>
      old.pulseValue != pulseValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerPainter — traveling highlight shimmer for rainbow specials
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerPainter extends CustomPainter {
  final double pulseValue;
  _ShimmerPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final shimmerX = -size.width * 0.3 + pulseValue * size.width * 1.6;
    final shimmerWidth = size.width * 0.3;
    final rect = Rect.fromLTWH(shimmerX, 0, shimmerWidth, size.height);

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withAlpha(0),
          Colors.white.withAlpha(40),
          Colors.white.withAlpha(0),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.pulseValue != pulseValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ObstacleOverlay — visual overlay for obstacles
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// _ObstacleOverlay — ultra-premium visual widgets for obstacles
// ─────────────────────────────────────────────────────────────────────────────

class _ObstacleOverlay extends StatelessWidget {
  final ObstacleType obstacle;
  final double cellSize;

  const _ObstacleOverlay({
    required this.obstacle,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    switch (obstacle) {
      case ObstacleType.ice1:
        return _IceObstacle(level: 1, cellSize: cellSize);
      case ObstacleType.ice2:
        return _IceObstacle(level: 2, cellSize: cellSize);
      case ObstacleType.box:
        return _WoodBoxObstacle(cellSize: cellSize);
      case ObstacleType.fog:
        return _FogObstacle(cellSize: cellSize);
      case ObstacleType.chain1:
        return _ChainsObstacle(level: 1, cellSize: cellSize);
      case ObstacleType.chain2:
        return _ChainsObstacle(level: 2, cellSize: cellSize);
      case ObstacleType.chocolate:
        return _ChocolateObstacle(cellSize: cellSize);
      case ObstacleType.honey:
        return _HoneyObstacle(cellSize: cellSize);
      case ObstacleType.portal:
        return Center(
          child: Container(
            width: cellSize * 0.75,
            height: cellSize * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFC77DFF), Color(0xFF7B2CBF), Color(0xFF3C096C)],
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xFF9D4EDD), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.cyclone, color: Colors.white, size: 18),
          ),
        );
      case ObstacleType.iceWall:
        return _IceObstacle(level: 2, cellSize: cellSize);
      case ObstacleType.bubble:
        return Center(
          child: Container(
            width: cellSize * 0.82,
            height: cellSize * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                radius: 0.9,
                colors: [
                  Colors.white.withAlpha(190),
                  const Color(0x6080D8FF),
                  const Color(0x30E040FB),
                  const Color(0x1000E5FF),
                ],
              ),
              border: Border.all(
                color: Colors.white.withAlpha(180),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x8080D8FF),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      case ObstacleType.none:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ❄️ _IceObstacle — realistic 3D frozen crystal ice with cracks & frost
// ─────────────────────────────────────────────────────────────────────────────

class _IceObstacle extends StatelessWidget {
  final int level;
  final double cellSize;

  const _IceObstacle({required this.level, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: level == 2
              ? [
                  const Color(0xCCB3E5FC),
                  const Color(0x994FC3F7),
                  const Color(0xBB0288D1),
                ]
              : [
                  const Color(0x99E1F5FE),
                  const Color(0x6681D4FA),
                  const Color(0x8829B6F6),
                ],
        ),
        border: Border.all(
          color: Colors.white.withAlpha(level == 2 ? 220 : 160),
          width: level == 2 ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withAlpha(level == 2 ? 140 : 80),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _IceCrackPainter(level: level),
          ),
          Positioned(
            top: 2,
            left: 4,
            child: Container(
              width: cellSize * 0.35,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withAlpha(180),
              ),
            ),
          ),
          if (level == 2)
            Center(
              child: Icon(
                Icons.ac_unit_rounded,
                size: cellSize * 0.38,
                color: Colors.white.withAlpha(190),
              ),
            ),
        ],
      ),
    );
  }
}

class _IceCrackPainter extends CustomPainter {
  final int level;
  _IceCrackPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(level == 2 ? 220 : 160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = level == 2 ? 1.6 : 1.2
      ..strokeCap = StrokeCap.round;

    final shadowPaint = Paint()
      ..color = const Color(0xFF01579B).withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeWidth = level == 2 ? 2.2 : 1.6;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.15, h * 0.20);
    path.lineTo(w * 0.38, h * 0.42);
    path.lineTo(w * 0.65, h * 0.35);
    path.lineTo(w * 0.85, h * 0.70);

    path.moveTo(w * 0.38, h * 0.42);
    path.lineTo(w * 0.30, h * 0.75);
    path.lineTo(w * 0.18, h * 0.85);

    if (level == 2) {
      path.moveTo(w * 0.65, h * 0.35);
      path.lineTo(w * 0.80, h * 0.18);
      path.moveTo(w * 0.50, h * 0.55);
      path.lineTo(w * 0.75, h * 0.80);
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IceCrackPainter old) => old.level != level;
}

// ─────────────────────────────────────────────────────────────────────────────
// ⛓️ _ChainsObstacle — 3D metallic iron chains with golden padlock
// ─────────────────────────────────────────────────────────────────────────────

class _ChainsObstacle extends StatelessWidget {
  final int level;
  final double cellSize;

  const _ChainsObstacle({required this.level, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        CustomPaint(
          painter: _HeavyChainPainter(level: level),
        ),
        Center(
          child: Container(
            width: cellSize * 0.36,
            height: cellSize * 0.42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TT.goldShine, TT.gold, TT.goldDeep],
              ),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(160),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: cellSize * 0.14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E2723),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3E2723),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeavyChainPainter extends CustomPainter {
  final int level;
  _HeavyChainPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawChainLine(Offset start, Offset end) {
      final linePaint = Paint()
        ..color = const Color(0xFF424242)
        ..strokeWidth = level == 2 ? 6.0 : 4.5
        ..strokeCap = StrokeCap.round;

      final highlightPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = level == 2 ? 2.5 : 1.8
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(start, end, linePaint);
      canvas.drawLine(start, end, highlightPaint);

      // Draw chain link rings along the line
      const steps = 4;
      for (int i = 0; i <= steps; i++) {
        final t = i / steps;
        final pt = Offset(
          start.dx + (end.dx - start.dx) * t,
          start.dy + (end.dy - start.dy) * t,
        );
        canvas.drawOval(
          Rect.fromCenter(center: pt, width: 8, height: 6),
          Paint()
            ..color = const Color(0xFFBDBDBD)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    drawChainLine(const Offset(4, 4), Offset(w - 4, h - 4));
    if (level == 2) {
      drawChainLine(Offset(w - 4, 4), Offset(4, h - 4));
    }
  }

  @override
  bool shouldRepaint(covariant _HeavyChainPainter old) => old.level != level;
}

// ─────────────────────────────────────────────────────────────────────────────
// 🍫 _ChocolateObstacle — delicious 3D chocolate bar tablet
// ─────────────────────────────────────────────────────────────────────────────

class _ChocolateObstacle extends StatelessWidget {
  final double cellSize;
  const _ChocolateObstacle({required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D3B1E), Color(0xFF4E2612), Color(0xFF331609)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFF8D4E27), width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildChocoSquare()),
                const SizedBox(width: 2),
                Expanded(child: _buildChocoSquare()),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildChocoSquare()),
                const SizedBox(width: 2),
                Expanded(child: _buildChocoSquare()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChocoSquare() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D4E27), Color(0xFF5A2C14), Color(0xFF3B1B0B)],
        ),
        border: Border.all(color: const Color(0xFFA05B30), width: 0.8),
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(40),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 📦 _WoodBoxObstacle — 3D tropical wooden crate with brass brackets & nails
// ─────────────────────────────────────────────────────────────────────────────

class _WoodBoxObstacle extends StatelessWidget {
  final double cellSize;
  const _WoodBoxObstacle({required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8860B), Color(0xFF8B5A2B), Color(0xFF5C3317)],
        ),
        border: Border.all(color: const Color(0xFFD2B48C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Diagonal X wood planks
          CustomPaint(painter: _WoodPlankPainter()),
          // 4 Brass corner studs
          for (final align in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: align,
              child: Container(
                margin: const EdgeInsets.all(2.5),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [TT.goldShine, TT.goldDeep],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WoodPlankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A2508)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    final highlight = Paint()
      ..color = const Color(0xFFCD853F)
      ..strokeWidth = 1.0;

    final m = size.width * 0.12;
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), paint);
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), highlight);

    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ☁️ _FogObstacle — mystical volumetric mist
// ─────────────────────────────────────────────────────────────────────────────

class _FogObstacle extends StatelessWidget {
  final double cellSize;
  const _FogObstacle({required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.85,
          colors: [
            Colors.white.withAlpha(200),
            const Color(0xCCB0BEC5),
            const Color(0x7778909C),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.cloud_queue_rounded,
          color: Colors.white,
          size: cellSize * 0.48,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🍯 _HoneyObstacle — viscous dripping amber honey
// ─────────────────────────────────────────────────────────────────────────────

class _HoneyObstacle extends StatelessWidget {
  final double cellSize;
  const _HoneyObstacle({required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFFF8F00)],
        ),
        border: Border.all(color: Colors.white.withAlpha(140), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x66FFB300), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.water_drop_rounded,
          color: Colors.white.withAlpha(220),
          size: cellSize * 0.44,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SelectionHighlight — golden glow pulsing border
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionHighlight extends StatelessWidget {
  final double pulseValue;
  final double cellSize;

  const _SelectionHighlight({
    required this.pulseValue,
    required this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 1.02 + pulseValue * 0.05;
    return Transform.scale(
      scale: scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TT.goldShine.withAlpha((180 + 75 * pulseValue).toInt()),
                  width: 3.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TT.goldBright.withAlpha((120 + 80 * pulseValue).toInt()),
                    blurRadius: 12 + pulseValue * 6,
                    spreadRadius: 2 + pulseValue * 2,
                  ),
                  BoxShadow(
                    color: Colors.white.withAlpha((140 * pulseValue).toInt()),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          for (final align in const [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: align,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: TT.goldShine,
                      blurRadius: 4,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HintHighlight — pulsing white glow border
// ─────────────────────────────────────────────────────────────────────────────

class _HintHighlight extends StatelessWidget {
  final double pulseValue;

  const _HintHighlight({required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    final alpha = (80 + (120 * pulseValue)).toInt();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withAlpha(alpha),
          width: 2.0 + pulseValue * 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withAlpha((30 + 40 * pulseValue).toInt()),
            blurRadius: 6 + pulseValue * 3,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainters for obstacles (kept lightweight)
// ─────────────────────────────────────────────────────────────────────────────

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA07820)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final m = size.width * 0.15;
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChainPainter extends CustomPainter {
  final int level;
  _ChainPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA0A0A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = level == 2 ? 3.0 : 2.0
      ..strokeCap = StrokeCap.round;
    final m = size.width * 0.15;
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────
// Tropical destroy burst — per-product particle effect when matched
// ─────────────────────────────────────────────────────────────────────────

({Color primary, Color accent, Color glow}) _palette(JellyType t) {
  switch (t) {
    case JellyType.purple: // coconut → brown wood + white meat
      return (
        primary: const Color(0xFF6B4226),
        accent: const Color(0xFFFFF1D9),
        glow: const Color(0xFF8B5A2B)
      );
    case JellyType.yellow: // pineapple → gold + green leaf
      return (
        primary: const Color(0xFFFFCB3D),
        accent: const Color(0xFF7BD66E),
        glow: const Color(0xFFFFE89C)
      );
    case JellyType.blue: // shell → turquoise water
      return (
        primary: const Color(0xFF26B89E),
        accent: const Color(0xFF8EE6D9),
        glow: const Color(0xFF6FD3E6)
      );
    case JellyType.green: // mango → fresh green
      return (
        primary: const Color(0xFF3CA84F),
        accent: const Color(0xFF7BD66E),
        glow: const Color(0xFFCFFF99)
      );
    case JellyType.pink: // hibiscus → pink petals
      return (
        primary: const Color(0xFFFF5A8E),
        accent: const Color(0xFFFFCB3D),
        glow: const Color(0xFFFFB3D1)
      );
    case JellyType.orange: // crab → orange shell
      return (
        primary: const Color(0xFFE85A5A),
        accent: const Color(0xFFFFCB3D),
        glow: const Color(0xFFFF8E7A)
      );
    case JellyType.black: // raven → blue shimmer + dark
      return (
        primary: const Color(0xFF1A1A2E),
        accent: const Color(0xFF4DA8FF),
        glow: const Color(0xFF8AC4FF)
      );
  }
}

/// Trailing dust behind a tile mid-swap — 4 fading dots strung along the
/// line from the tile's start position to its current position. Pure
/// decoration; cleans up when the move animation ends.
class _SwapDustPainter extends CustomPainter {
  final JellyType jellyType;
  final double progress;
  final Offset travel;
  final double cellSize;

  _SwapDustPainter({
    required this.jellyType,
    required this.progress,
    required this.travel,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05 || progress >= 0.98) return;
    // Paint container is 2× cellSize; the cell sits at the middle. The
    // tile has already been moved by transform — we draw dust BEHIND
    // its current position (toward the start, opposite of travel).
    final center = Offset(size.width / 2, size.height / 2);
    final pal = _palette(jellyType);

    // Distance the cell has moved so far.
    final movedDx = travel.dx * progress;
    final movedDy = travel.dy * progress;
    // Direction back toward start (unit-ish):
    final lenSq = movedDx * movedDx + movedDy * movedDy;
    if (lenSq < 1) return;
    final len = sqrt(lenSq);
    final ux = -movedDx / len;
    final uy = -movedDy / len;

    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    // 4 dust particles spaced along the trail.
    for (int i = 0; i < 4; i++) {
      final dist = (i + 0.7) * (cellSize * 0.18);
      if (dist > len * 1.1) continue;
      // Each particle's "age" — older particles fade more.
      final age = (i / 4.0).clamp(0.0, 1.0);
      final fadeIn = (progress / 0.18).clamp(0.0, 1.0);
      final alpha = ((1 - age) * 180 * fadeIn * (1 - progress)).toInt().clamp(0, 180);
      // Slight perpendicular jitter so particles don't form a straight
      // boring line. Use position-derived seed.
      final perp = Offset(-uy, ux);
      final jitter = (i.isEven ? 1.0 : -1.0) * (cellSize * 0.08);
      final p = center + Offset(ux * dist, uy * dist) + perp * jitter;
      paint.color = pal.accent.withAlpha(alpha);
      canvas.drawCircle(p, cellSize * 0.07 * (1 - age * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwapDustPainter old) =>
      old.progress != progress || old.travel != travel;
}

/// Brief golden halo that flashes around a tile for ~120ms RIGHT BEFORE
/// it gets destroyed — gives the player a beat of "yes, this matched!"
/// anticipation. Two concentric rings + radial glow.
class _PreMatchGlowPainter extends CustomPainter {
  final double progress;
  _PreMatchGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final t = progress;
    // Radius grows from 0.6r → 0.95r over the brief window.
    final baseR = (size.width * 0.5) * (0.6 + 0.35 * t);
    // Alpha peaks at t=0.5 then fades — gives a "blink" feel.
    final alpha = (sin(t * pi) * 235).toInt().clamp(0, 235);

    // Soft halo gradient
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE89C).withAlpha(alpha),
          const Color(0xFFFFC25C).withAlpha((alpha * 0.55).toInt()),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: baseR));
    canvas.drawCircle(c, baseR, halo);

    // Bright outer ring stroke.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFFAD8).withAlpha((alpha * 0.9).toInt());
    canvas.drawCircle(c, baseR * 0.88, ring);

    // Tiny sparkles at 4 cardinal points to sell the "magic match" idea.
    final sparkle = Paint()
      ..color = const Color(0xFFFFFAD8).withAlpha(alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final r2 = baseR * 0.92;
    for (int i = 0; i < 4; i++) {
      final ang = i * (pi / 2) + t * pi;
      canvas.drawCircle(
        Offset(c.dx + cos(ang) * r2, c.dy + sin(ang) * r2),
        2.5,
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreMatchGlowPainter old) => old.progress != progress;
}

class _TropicalBurstPainter extends CustomPainter {
  final JellyType jellyType;
  final double progress;

  _TropicalBurstPainter({required this.jellyType, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final pal = _palette(jellyType);

    // Soft glow ring expanding outward
    final glowT = (progress / 0.5).clamp(0.0, 1.0);
    final ringR = maxR * (0.25 + glowT * 0.55);
    final ringAlpha = (220 * (1 - progress)).toInt().clamp(0, 220);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..color = pal.glow.withAlpha(ringAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 14 primary particles flying radially outward — denser dopamine.
    const n = 14;
    final outR = maxR * (0.15 + progress * 0.85);
    final particleAlpha = ((1 - progress) * 240).toInt().clamp(0, 240);
    final particleSize = (1.0 - progress * 0.5) * maxR * 0.16;

    for (int i = 0; i < n; i++) {
      final angle = i * (2 * pi / n) + progress * 0.6;
      final px = c.dx + cos(angle) * outR;
      final py = c.dy + sin(angle) * outR;
      _drawShape(canvas, Offset(px, py), particleSize, angle, pal.primary, particleAlpha);
    }

    // 8 accent particles smaller — fills the gaps between primary spokes.
    const n2 = 8;
    final outR2 = maxR * (0.1 + progress * 0.7);
    final particleSize2 = (1.0 - progress * 0.5) * maxR * 0.12;
    for (int i = 0; i < n2; i++) {
      final angle = i * (2 * pi / n2) + pi / n2 + progress * -0.4;
      final px = c.dx + cos(angle) * outR2;
      final py = c.dy + sin(angle) * outR2;
      _drawAccent(canvas, Offset(px, py), particleSize2, pal.accent, particleAlpha);
    }

    // Secondary slow drift — 6 tiny dots that linger after the main blast.
    if (progress > 0.25) {
      const n3 = 6;
      final lateT = ((progress - 0.25) / 0.75).clamp(0.0, 1.0);
      final outR3 = maxR * (0.3 + lateT * 0.55);
      final lateAlpha = ((1 - lateT) * 200).toInt().clamp(0, 200);
      final dotPaint = Paint()
        ..color = pal.accent.withAlpha(lateAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      for (int i = 0; i < n3; i++) {
        final ang = i * (2 * pi / n3) + lateT * 1.2;
        final px = c.dx + cos(ang) * outR3;
        final py = c.dy + sin(ang) * outR3 + lateT * 4; // slight gravity
        canvas.drawCircle(Offset(px, py), maxR * 0.04 * (1 - lateT * 0.6), dotPaint);
      }
    }

    // Bright center flash
    if (progress < 0.3) {
      final flashAlpha = ((1 - progress / 0.3) * 240).toInt().clamp(0, 240);
      canvas.drawCircle(
        c,
        maxR * 0.25 * (1 - progress / 0.3),
        Paint()
          ..color = Colors.white.withAlpha(flashAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawShape(Canvas canvas, Offset center, double size, double rotation,
      Color color, int alpha) {
    final paint = Paint()..color = color.withAlpha(alpha);
    final shadow = Paint()
      ..color = Colors.black.withAlpha((alpha * 0.4).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    switch (jellyType) {
      case JellyType.purple:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: size * 1.6, height: size),
          Radius.circular(size * 0.3),
        );
        canvas.drawRRect(rect.shift(const Offset(0, 1)), shadow);
        canvas.drawRRect(rect, paint);
        break;
      case JellyType.yellow:
        _starShape(canvas, size, paint, shadow, points: 4);
        break;
      case JellyType.blue:
        final path = Path()
          ..moveTo(0, -size)
          ..quadraticBezierTo(size * 0.7, -size * 0.2, size * 0.5, size * 0.4)
          ..quadraticBezierTo(0, size * 0.9, -size * 0.5, size * 0.4)
          ..quadraticBezierTo(-size * 0.7, -size * 0.2, 0, -size)
          ..close();
        canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
        canvas.drawPath(path, paint);
        break;
      case JellyType.green:
        final path = Path()
          ..moveTo(0, -size)
          ..quadraticBezierTo(size * 0.8, -size * 0.3, 0, size)
          ..quadraticBezierTo(-size * 0.8, -size * 0.3, 0, -size)
          ..close();
        canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
        canvas.drawPath(path, paint);
        break;
      case JellyType.pink:
        _starShape(canvas, size, paint, shadow, points: 5);
        break;
      case JellyType.orange:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = i * (pi / 3);
          final px = cos(a) * size * 0.7;
          final py = sin(a) * size * 0.7;
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
        canvas.drawPath(path, paint);
        break;
      case JellyType.black:
        // Black raven → diamond/feather shape
        final path = Path()
          ..moveTo(0, -size)
          ..lineTo(size * 0.7, 0)
          ..lineTo(0, size)
          ..lineTo(-size * 0.7, 0)
          ..close();
        canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
        canvas.drawPath(path, paint);
        break;
    }
    canvas.restore();
  }

  void _starShape(Canvas canvas, double size, Paint fill, Paint shadow,
      {required int points}) {
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? size : size * 0.45;
      final a = -pi / 2 + i * pi / points;
      final px = cos(a) * r;
      final py = sin(a) * r;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
    canvas.drawPath(path, fill);
  }

  void _drawAccent(Canvas canvas, Offset center, double size, Color color, int alpha) {
    canvas.drawCircle(
      center,
      size * 0.6,
      Paint()
        ..color = color.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      center,
      size * 0.3,
      Paint()..color = Colors.white.withAlpha((alpha * 0.7).toInt()),
    );
  }

  @override
  bool shouldRepaint(covariant _TropicalBurstPainter old) =>
      old.progress != progress || old.jellyType != jellyType;
}

// ─────────────────────────────────────────────────────────────────────────
// Special spawn burst — dramatic rainbow shockwave when 4/5/6+ matches
// create a power-up tile. Multi-layer: outer rainbow ring + center white
// flash + 12 colored sparkles spiraling outward + 2 expanding gold rings.
// ─────────────────────────────────────────────────────────────────────────

class _SpecialSpawnPainter extends CustomPainter {
  final double progress; // 0..1
  _SpecialSpawnPainter({required this.progress});

  static const _rainbow = [
    Color(0xFFFF5A8E), // pink
    Color(0xFFFF801A), // orange
    Color(0xFFFFD91A), // yellow
    Color(0xFF33D973), // green
    Color(0xFF338CFF), // blue
    Color(0xFF8B24DB), // purple
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 1) Outer expanding rainbow rings (2 staggered)
    for (int i = 0; i < 2; i++) {
      final ringT = (progress - i * 0.15).clamp(0.0, 1.0);
      if (ringT <= 0) continue;
      final ringR = maxR * (0.2 + ringT * 0.85);
      final ringAlpha = ((1 - ringT) * 220).toInt().clamp(0, 220);
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..shader = SweepGradient(
            colors: [..._rainbow, _rainbow.first],
            transform: GradientRotation(progress * 6.28),
          ).createShader(Rect.fromCircle(center: c, radius: ringR))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // alpha overlay
      canvas.drawCircle(
        c,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withAlpha(ringAlpha),
      );
    }

    // 2) Center radial gold burst (peaks at t=0.3)
    final flashT = (progress / 0.5).clamp(0.0, 1.0);
    final flashAlpha = (((1 - flashT) * 240)).toInt().clamp(0, 240);
    canvas.drawCircle(
      c,
      maxR * (0.15 + flashT * 0.3),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha(flashAlpha),
            const Color(0xFFFFCB3D).withAlpha((flashAlpha * 0.6).toInt()),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: maxR * 0.5)),
    );

    // 3) 12 colored sparkles spiraling outward
    const n = 12;
    for (int i = 0; i < n; i++) {
      final angle = i * (3.14159 * 2 / n) + progress * 1.5;
      final r = maxR * (0.25 + progress * 0.7);
      final px = c.dx + cos(angle) * r;
      final py = c.dy + sin(angle) * r;
      final sparkSize = (1 - progress * 0.5) * maxR * 0.06;
      final color = _rainbow[i % _rainbow.length];
      final alpha = ((1 - progress) * 240).toInt().clamp(0, 240);
      // halo
      canvas.drawCircle(
        Offset(px, py),
        sparkSize * 1.8,
        Paint()
          ..color = color.withAlpha(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      // bright core
      canvas.drawCircle(
        Offset(px, py),
        sparkSize * 0.7,
        Paint()..color = Colors.white.withAlpha(alpha),
      );
    }

    // 4) 4 cross rays (sharp white lines from center)
    if (progress < 0.5) {
      final rayAlpha = (((1 - progress / 0.5)) * 220).toInt().clamp(0, 220);
      final rayLen = maxR * (0.5 + progress * 0.5);
      final rayPaint = Paint()
        ..color = Colors.white.withAlpha(rayAlpha)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 4; i++) {
        final a = i * (3.14159 / 2) + progress * 0.3;
        canvas.drawLine(
          Offset(c.dx + cos(a) * 10, c.dy + sin(a) * 10),
          Offset(c.dx + cos(a) * rayLen, c.dy + sin(a) * rayLen),
          rayPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpecialSpawnPainter old) =>
      old.progress != progress;
}

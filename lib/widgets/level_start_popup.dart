import 'package:flutter/material.dart';

import 'package:patpat_game/game/level_generator.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/tropical/island_button.dart';
import 'package:patpat_game/widgets/tropical/island_chip.dart';
import 'package:patpat_game/widgets/tropical/island_panel.dart';
import 'package:patpat_game/widgets/tropical/shell_strip.dart';

class LevelStartPopup extends StatefulWidget {
  final int level;
  final int earnedStars;
  final int highScore;
  final int hammerCount;
  final int colorBlastCount;
  final int extraMovesCount;
  final VoidCallback onPlay;
  final VoidCallback onClose;

  const LevelStartPopup({
    super.key,
    required this.level,
    required this.earnedStars,
    required this.highScore,
    this.hammerCount = 0,
    this.colorBlastCount = 0,
    this.extraMovesCount = 0,
    required this.onPlay,
    required this.onClose,
  });

  @override
  State<LevelStartPopup> createState() => _LevelStartPopupState();
}

class _LevelStartPopupState extends State<LevelStartPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = GameRegion.forLevel(widget.level);

    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withAlpha(180),
        child: Center(
          child: AnimatedBuilder(
            animation: _enter,
            builder: (_, child) {
              final t = Curves.easeOutBack.transform(_enter.value.clamp(0, 1));
              return Opacity(
                opacity: _enter.value.clamp(0, 1),
                child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
              );
            },
            child: GestureDetector(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: IslandPanel(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Level number badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: TT.coralButtonGradient,
                                border: Border.all(color: TT.goldShine, width: 2),
                                boxShadow: [
                                  BoxShadow(color: TT.coral.withAlpha(160), blurRadius: 14, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag_rounded, color: TT.goldShine, size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    'BÖLÜM ${widget.level}',
                                    style: TT.titleLarge.copyWith(
                                      color: TT.sandLight,
                                      letterSpacing: 1.4,
                                      fontSize: 20,
                                      shadows: [
                                        Shadow(color: Colors.black.withAlpha(220), blurRadius: 4, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            ShellStrip(filled: widget.earnedStars, size: 28, animate: false),
                            const SizedBox(height: 8),
                            IslandChip(
                              text: region.displayName,
                              icon: Icons.terrain_rounded,
                              bg: TT.gold,
                              fontSize: 12,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            ),
                            if (widget.highScore > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                'En yüksek puan: ${widget.highScore}',
                                style: TT.bodySmall.copyWith(color: TT.driftWoodDark, fontWeight: FontWeight.w800),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // ─── Hedef Paneli (Candy Crush tarzı) ───
                            _GoalsPanel(level: widget.level),
                            const SizedBox(height: 14),
                            // Booster slots — visual placeholders only (purchase via shop)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _BoosterSlot(asset: TA.boosterHammer, count: widget.hammerCount),
                                _BoosterSlot(asset: TA.boosterColorBlast, count: widget.colorBlastCount),
                                _BoosterSlot(asset: TA.boosterExtraMoves, count: widget.extraMovesCount),
                              ],
                            ),
                            const SizedBox(height: 16),
                            IslandButton(
                              text: 'OYNA',
                              icon: Icons.play_arrow_rounded,
                              color: IslandButtonColor.palm,
                              size: IslandButtonSize.large,
                              fullWidth: true,
                              onPressed: widget.onPlay,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Close button (top-right)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: TT.coralButtonGradient,
                            border: Border.all(color: TT.goldShine, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(180), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Candy Crush style goals panel — shows level number, moves, and required
/// jelly collections in a single dark plaque so the player knows EXACTLY what
/// they need to do.
class _GoalsPanel extends StatelessWidget {
  final int level;
  const _GoalsPanel({required this.level});

  @override
  Widget build(BuildContext context) {
    // Generate level config to discover goals + moves.
    final config = LevelGenerator.generate(level);
    final moves = config.maxMoves;
    final goals = config.goals;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B6F4A), Color(0xFF5C4A2D), Color(0xFF3D2F1A)],
        ),
        border: Border.all(color: TT.goldShine.withAlpha(180), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: "HEDEFLER" + moves chip
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: TT.goldShine, size: 16),
              const SizedBox(width: 6),
              Text(
                'HEDEFLER',
                style: TextStyle(
                  color: TT.goldShine,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black.withAlpha(220), blurRadius: 2, offset: const Offset(0, 1))],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [TT.palmLight, TT.palm, TT.palmDark],
                  ),
                  border: Border.all(color: TT.goldShine, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '$moves hamle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Goal items (jelly + count, candy-crush style)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: goals
                .where((g) => g.goalType == GoalType.collectJelly)
                .take(4)
                .map((g) => _GoalItem(jelly: g.jellyType, count: g.count))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _GoalItem extends StatelessWidget {
  final JellyType jelly;
  final int count;
  const _GoalItem({required this.jelly, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withAlpha(140),
        border: Border.all(color: TT.gold.withAlpha(160), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/sprites/jelly_${jelly.name}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.help_outline, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'x$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterSlot extends StatelessWidget {
  final String asset;
  final int count;
  const _BoosterSlot({required this.asset, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: TT.sandPanelGradient,
        border: Border.all(color: TT.gold, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.bolt_rounded, color: TT.gold, size: 36),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: TT.coralButtonGradient,
              border: Border.all(color: TT.goldShine, width: 1),
            ),
            child: Text(
              'x$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

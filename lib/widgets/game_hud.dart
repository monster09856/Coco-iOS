import 'package:flutter/material.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/theme/tropical_theme.dart';

/// Fully transparent top HUD — only floating chips, no panel background.
/// Layout: [back-circle] [score-pill] [BÖLÜM red] [HAMLE green] [pause]
class GameHud extends StatelessWidget {
  final int level;
  final int movesLeft;
  final int score;
  final int timeLeft;
  final List<LevelGoal> goals; // unused but keep API stable
  final VoidCallback onPause;
  final VoidCallback onBack;

  const GameHud({
    super.key,
    required this.level,
    required this.movesLeft,
    required this.score,
    required this.timeLeft,
    required this.goals,
    required this.onPause,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Row(
            children: [
              _CircleBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 6),
              Expanded(
                child: _CountPill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: TT.coralLight,
                  value: '$score',
                ),
              ),
              const SizedBox(width: 5),
              _BadgePill(
                label: 'BÖLÜM',
                value: '$level',
                bgGradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [TT.coralLight, TT.coral, TT.coralDark],
                ),
              ),
              const SizedBox(width: 5),
              _BadgePill(
                label: timeLeft > 0 ? 'SÜRE' : 'HAMLE',
                value: timeLeft > 0 ? '$timeLeft' : '$movesLeft',
                bgGradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [TT.palmLight, TT.palm, TT.palmDark],
                ),
              ),
              const SizedBox(width: 6),
              _CircleBtn(icon: Icons.pause_rounded, onTap: onPause),
            ],
          ),
        ),
        // Compact goals strip — current/total per goal as floating chips.
        if (goals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: _GoalsStrip(goals: goals),
          ),
      ],
    );
  }
}

/// Live goals strip shown below the HUD — each goal is a small chip with
/// its icon/sprite + remaining count. Updates as the player progresses.
class _GoalsStrip extends StatelessWidget {
  final List<LevelGoal> goals;
  const _GoalsStrip({required this.goals});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    final displayGoals = goals.take(4).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < displayGoals.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _GoalChip(goal: displayGoals[i]),
        ],
      ],
    );
  }
}

class _GoalChip extends StatelessWidget {
  final LevelGoal goal;
  const _GoalChip({required this.goal});

  Widget _buildGoalIcon() {
    switch (goal.goalType) {
      case GoalType.collectJelly:
        return Image.asset(
          'assets/sprites/jelly_${goal.jellyType.name}.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.star, color: Colors.amber, size: 14),
        );
      case GoalType.breakIce:
        return const Icon(Icons.ac_unit_rounded, color: Color(0xFF70D6FF), size: 16);
      case GoalType.clearChocolate:
        return const Icon(Icons.cookie_rounded, color: Color(0xFFFF9F1C), size: 16);
      case GoalType.makeCombos:
        return const Icon(Icons.bolt_rounded, color: Color(0xFFFFD166), size: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (goal.count - goal.collected).clamp(0, goal.count);
    final done = remaining == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withAlpha(160),
        border: Border.all(
          color: done ? TT.palm : TT.gold.withAlpha(180),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 4, offset: const Offset(0, 2)),
          if (done) BoxShadow(color: TT.palm.withAlpha(140), blurRadius: 8, spreadRadius: -1),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white12,
            ),
            padding: const EdgeInsets.all(1),
            child: _buildGoalIcon(),
          ),
          const SizedBox(width: 4),
          Text(
            done ? '✓' : '$remaining',
            style: TextStyle(
              color: done ? TT.palm : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black.withAlpha(220), blurRadius: 2, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  const _CountPill({required this.icon, required this.iconColor, required this.value});

  @override
  State<_CountPill> createState() => _CountPillState();
}

class _CountPillState extends State<_CountPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int? _displayedValue;
  int? _fromValue;
  int? _toValue;
  // Pulse on increase (separate from numeric tween).
  late final AnimationController _pulse;

  int? _parse(String v) => int.tryParse(v.replaceAll(RegExp(r'\D'), ''));

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _ctrl.addListener(() {
      if (_fromValue != null && _toValue != null) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        final v = (_fromValue! + (_toValue! - _fromValue!) * t).round();
        if (v != _displayedValue) setState(() => _displayedValue = v);
      }
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _displayedValue = _parse(widget.value);
  }

  @override
  void didUpdateWidget(covariant _CountPill old) {
    super.didUpdateWidget(old);
    final newN = _parse(widget.value);
    if (newN == null) return;
    if (_displayedValue == null) {
      _displayedValue = newN;
      return;
    }
    if (newN == _displayedValue) return;
    // Snap-tween from current shown value to new target.
    _fromValue = _displayedValue;
    _toValue = newN;
    _ctrl.forward(from: 0);
    if (newN > (_fromValue ?? 0)) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _displayedValue?.toString() ?? widget.value;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pt = _pulse.value;
        final scale = 1.0 +
            (pt < 0.4
                ? (pt / 0.4) * 0.10
                : (1 - (pt - 0.4) / 0.6) * 0.10);
        return Transform.scale(
          scale: scale,
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [TT.goldShine, TT.gold, TT.goldDeep],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 6, offset: const Offset(0, 2)),
                if (pt > 0)
                  BoxShadow(
                    color: TT.goldShine.withAlpha((180 * (1 - pt)).toInt()),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
              ],
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE6B0), Color(0xFFC79A52)],
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 18, shadows: [
                    Shadow(color: Colors.black.withAlpha(160), blurRadius: 3, offset: const Offset(0, 1)),
                  ]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: TT.driftWoodDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.white.withAlpha(160), blurRadius: 1, offset: const Offset(0, 1)),
                        ],
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

class _BadgePill extends StatelessWidget {
  final String label;
  final String value;
  final LinearGradient bgGradient;
  const _BadgePill({required this.label, required this.value, required this.bgGradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TT.goldShine, TT.gold, TT.goldDeep],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 6, offset: const Offset(0, 2)),
          BoxShadow(color: TT.gold.withAlpha(100), blurRadius: 12, spreadRadius: -2),
        ],
      ),
      padding: const EdgeInsets.all(1.5),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: bgGradient,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: TT.goldShine,
                      letterSpacing: 0.5,
                      height: 1,
                      shadows: [Shadow(color: Colors.black.withAlpha(220), blurRadius: 2, offset: const Offset(0, 1))],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.05,
                      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // top inner highlight band (gloss)
          Positioned(
            top: 1,
            left: 4,
            right: 4,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha(120),
                    Colors.white.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TT.goldShine, TT.gold, TT.goldDeep],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(150), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE6B0), Color(0xFFC79A52)],
            ),
          ),
          child: Icon(icon, color: TT.driftWoodDark, size: 18),
        ),
      ),
    );
  }
}

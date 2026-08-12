import 'dart:math';

import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/models/position.dart';

/// Generates [LevelConfig] for all 240 levels using a sigmoid difficulty curve,
/// symmetric obstacle placement, and region-aware goal/obstacle scaling.
class LevelGenerator {

  /// Sigmoid difficulty curve with sinusoidal micro-variation.
  /// Returns a value clamped to [0, 1].
  static double calculateDifficulty(int level) {
    final x = (level - 1) / 239.0;
    final sigmoid = 1.0 / (1.0 + exp(-9.0 * (x - 0.5)));
    final variation = 0.03 * sin(level * 0.15);
    return (sigmoid + variation).clamp(0.0, 1.0);
  }

  /// Generates a complete [LevelConfig] for the given [level] (1..240).
  static LevelConfig generate(int level) {
    assert(level >= 1 && level <= 240, 'Level must be between 1 and 240');

    // Seed RNG deterministically per level for reproducible generation.
    final rng = Random(level * 7919);

    final difficulty = calculateDifficulty(level);
    final region = GameRegion.forLevel(level);
    final isBoss = level > 0 && level % 20 == 0;
    final isMiniBoss = level > 0 && level % 10 == 0 && level % 20 != 0;
    final colors = _availableColors(level);

    final moves = _calculateMoves(level, difficulty, region, isBoss, isMiniBoss);
    final targetScore =
        _calculateTargetScore(level, difficulty, isBoss, isMiniBoss);
    final timeLimit = _calculateTimeLimit(level, isBoss, isMiniBoss);
    final goals =
        _generateGoals(level, difficulty, isBoss, isMiniBoss, region, colors, rng);
    final obstacles =
        _generateObstacles(level, difficulty, region, isBoss, isMiniBoss, rng);

    return LevelConfig(
      levelNumber: level,
      rows: 9,
      cols: 7,
      maxMoves: moves,
      goals: goals,
      obstacles: obstacles,
      availableTypes: colors,
      region: region,
      targetScore: targetScore,
      timeLimit: timeLimit,
    );
  }

  // ---------------------------------------------------------------------------
  // Move calculation
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Move calculation — Gold Standard balance (never fewer than 18 moves)
  // ---------------------------------------------------------------------------

  static int _calculateMoves(
    int level,
    double difficulty,
    GameRegion region,
    bool isBoss,
    bool isMiniBoss,
  ) {
    double base;
    if (level <= 5) {
      base = 32;
    } else if (level <= 15) {
      base = 29;
    } else if (level <= 30) {
      base = 27;
    } else if (level <= 60) {
      base = 25 - difficulty * 2;
    } else if (level <= 100) {
      base = 24 - difficulty * 2;
    } else if (level <= 150) {
      base = 22 - difficulty * 2;
    } else if (level <= 200) {
      base = 21 - difficulty * 2;
    } else {
      base = 20 - difficulty * 2;
    }

    if (isBoss) base += 4;
    if (isMiniBoss) base += 2;

    return base.round().clamp(18, 35);
  }

  // ---------------------------------------------------------------------------
  // Target score
  // ---------------------------------------------------------------------------

  static int _calculateTargetScore(
    int level,
    double difficulty,
    bool isBoss,
    bool isMiniBoss,
  ) {
    double base;
    if (level <= 3) {
      base = 250;
    } else if (level <= 8) {
      base = 380;
    } else if (level <= 15) {
      base = 520;
    } else if (level <= 25) {
      base = 680;
    } else if (level <= 40) {
      base = 820;
    } else if (level <= 60) {
      base = 980;
    } else if (level <= 80) {
      base = 1140;
    } else if (level <= 100) {
      base = 1300;
    } else if (level <= 120) {
      base = 1450;
    } else if (level <= 140) {
      base = 1600;
    } else if (level <= 160) {
      base = 1750;
    } else if (level <= 180) {
      base = 1900;
    } else if (level <= 200) {
      base = 2050;
    } else {
      base = 2200;
    }

    base += difficulty * 320;
    if (isBoss) base += 500;
    if (isMiniBoss) base += 250;

    return base.round().clamp(250, 3500);
  }

  // ---------------------------------------------------------------------------
  // Time limit
  // ---------------------------------------------------------------------------

  static int _calculateTimeLimit(int level, bool isBoss, bool isMiniBoss) {
    if (isBoss && level >= 21) {
      return 80 + max(0, 120 - level);
    }
    if (isMiniBoss && level >= 41) {
      return 100;
    }
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Available jelly colors
  // ---------------------------------------------------------------------------

  static List<JellyType> _availableColors(int level) {
    if (level <= 2) {
      return const [
        JellyType.purple,
        JellyType.yellow,
        JellyType.blue,
        JellyType.green,
      ];
    }
    if (level <= 15) {
      final useRed = level.isOdd;
      return [
        if (useRed) JellyType.purple else JellyType.pink,
        JellyType.yellow,
        JellyType.blue,
        JellyType.green,
        if (!useRed) JellyType.orange,
      ];
    }
    final rng = Random(level * 7919);
    final useRed = rng.nextBool();
    final includeBlack = rng.nextDouble() < 0.35;
    final colors = <JellyType>[
      JellyType.yellow,
      JellyType.blue,
      JellyType.green,
      if (useRed) JellyType.purple
      else ...[
        JellyType.pink,
        JellyType.orange,
      ],
    ];
    if (includeBlack) colors.add(JellyType.black);
    return colors;
  }

  // ---------------------------------------------------------------------------
  // Goal generation — Perfectly balanced, engaging targets
  // ---------------------------------------------------------------------------

  static List<LevelGoal> _generateGoals(
    int level,
    double difficulty,
    bool isBoss,
    bool isMiniBoss,
    GameRegion region,
    List<JellyType> colors,
    Random rng,
  ) {
    int goalCount;
    if (level <= 3) {
      goalCount = 1;
    } else if (level <= 10) {
      goalCount = rng.nextBool() ? 1 : 2;
    } else if (level <= 30) {
      goalCount = 2;
    } else {
      goalCount = rng.nextInt(2) + 2; // 2 or 3
    }

    double baseCount;
    if (level <= 3) {
      baseCount = 10 + level * 2;
    } else if (level <= 10) {
      baseCount = 14 + level * 1.5;
    } else if (level <= 30) {
      baseCount = 18 + difficulty * 6;
    } else if (level <= 60) {
      baseCount = 22 + difficulty * 6;
    } else if (level <= 100) {
      baseCount = 25 + difficulty * 7;
    } else if (level <= 150) {
      baseCount = 28 + difficulty * 8;
    } else if (level <= 200) {
      baseCount = 31 + difficulty * 8;
    } else {
      baseCount = 34 + difficulty * 8;
    }

    if (isBoss) baseCount *= 1.25;
    if (isMiniBoss) baseCount *= 1.15;

    const indexMultipliers = [1.0, 0.8, 0.65];
    final shuffled = List<JellyType>.from(colors)..shuffle(rng);

    final goals = <LevelGoal>[];
    for (var i = 0; i < goalCount; i++) {
      final multiplier = indexMultipliers[i];
      final count = (baseCount * multiplier).round().clamp(6, 45);
      goals.add(LevelGoal(
        jellyType: shuffled[i % shuffled.length],
        count: count,
      ));
    }

    return goals;
  }

  // ---------------------------------------------------------------------------
  // Obstacle generation — Capped for fun combos and healthy board space
  // ---------------------------------------------------------------------------

  static Map<Position, ObstacleType> _generateObstacles(
    int level,
    double difficulty,
    GameRegion region,
    bool isBoss,
    bool isMiniBoss,
    Random rng,
  ) {
    if (level < 9) return const {};

    final available = _availableObstacles(level, region);
    if (available.isEmpty) return const {};

    int minCount, maxCount;
    if (level < 20) {
      minCount = 2;
      maxCount = 4;
    } else if (level < 50) {
      minCount = 4;
      maxCount = 6;
    } else if (level < 100) {
      minCount = 4;
      maxCount = 8;
    } else if (level < 160) {
      minCount = 6;
      maxCount = 10;
    } else {
      minCount = 6;
      maxCount = 12;
    }

    double count = (minCount + rng.nextInt(maxCount - minCount + 1)).toDouble();
    if (isBoss) count *= 1.3;
    if (isMiniBoss) count *= 1.15;

    final totalCount = count.round().clamp(2, 14);

    const rows = 9;
    final obstacles = <Position, ObstacleType>{};

    var attempts = 0;
    while (obstacles.length < totalCount && attempts < 200) {
      attempts++;
      final row = rng.nextInt(rows);
      final col = rng.nextInt(4);
      final pos = Position(row, col);

      if (obstacles.containsKey(pos)) continue;

      final obstacleType = available[rng.nextInt(available.length)];
      obstacles[pos] = obstacleType;

      if (col < 3) {
        final mirrorPos = Position(row, 6 - col);
        if (!obstacles.containsKey(mirrorPos) &&
            obstacles.length < totalCount) {
          obstacles[mirrorPos] = obstacleType;
        }
      }

      if (obstacles.length >= totalCount) break;
    }

    return obstacles;
  }

  // ---------------------------------------------------------------------------
  // Available obstacle types by level/region
  // ---------------------------------------------------------------------------

  static List<ObstacleType> _availableObstacles(int level, GameRegion region) {
    final result = <ObstacleType>[];
    if (level >= 9) result.add(ObstacleType.ice1);
    if (level >= 10) result.add(ObstacleType.ice2);
    if (level >= 14) result.add(ObstacleType.box);
    if (level >= 24) result.add(ObstacleType.chain1);
    if (level >= 34) result.add(ObstacleType.fog);
    if (level >= 46) result.add(ObstacleType.chain2);
    if (level >= 58) result.add(ObstacleType.honey);
    if (level >= 72) result.add(ObstacleType.chocolate);
    return result;
  }
}

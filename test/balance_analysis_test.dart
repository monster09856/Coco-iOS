import 'package:flutter_test/flutter_test.dart';
import 'package:patpat_game/game/level_generator.dart';

void main() {
  test('Analyze all 240 levels for fairness, move sufficiency and beatability', () {
    final issues = <String>[];
    int totalImpossible = 0;

    print('=== 240 LEVEL BALANCE & BEATABILITY REPORT ===');
    for (int lvl = 1; lvl <= 240; lvl++) {
      final config = LevelGenerator.generate(lvl);
      int totalGoalJellies = 0;
      for (final g in config.goals) {
        totalGoalJellies += g.count;
      }

      final moves = config.maxMoves;
      final obstacles = config.obstacles.length;
      final jelliesPerMove = totalGoalJellies / moves;

      // In match-3, average matched jellies per move (with cascades/specials) is ~4.0 to 6.5.
      // If a level demands > 5.5 specific color jellies per move in early/mid game or > 7.0 in late game, it is nearly impossible.
      if (jelliesPerMove > 6.0) {
        issues.add(
          'Level $lvl: $moves moves, $totalGoalJellies total goal jellies (${jelliesPerMove.toStringAsFixed(1)}/move), $obstacles obstacles -> TOO HARD / NEARLY UNBEATABLE',
        );
        totalImpossible++;
      }
    }

    print('Analyzed 240 levels. Found $totalImpossible problematic levels.');
    for (final issue in issues.take(15)) {
      print(' - $issue');
    }
    if (issues.length > 15) {
      print(' ... and ${issues.length - 15} more');
    }
  });
}

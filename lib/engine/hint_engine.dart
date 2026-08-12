import 'package:patpat_game/engine/match_engine.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/game_grid.dart';
import 'package:patpat_game/models/position.dart';

/// Provides hint and deadlock detection for the game grid.
class HintEngine {
  HintEngine._();

  // ──────────────────────────────────────────────
  // 1. findHint
  // ──────────────────────────────────────────────

  /// Iterates all positions, checks right and down neighbors.
  /// Returns the first valid swap pair, or null if no valid move exists.
  static (Position, Position)? findHint(GameGrid grid) {
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final pos = Position(r, c);

        // Check right neighbor
        if (c + 1 < grid.cols) {
          final right = Position(r, c + 1);
          if (MatchEngine.isValidSwap(grid, pos, right)) {
            return (pos, right);
          }
        }

        // Check down neighbor
        if (r + 1 < grid.rows) {
          final down = Position(r + 1, c);
          if (MatchEngine.isValidSwap(grid, pos, down)) {
            return (pos, down);
          }
        }
      }
    }

    return null;
  }

  // ──────────────────────────────────────────────
  // 2. hasValidMoves
  // ──────────────────────────────────────────────

  /// Returns true if at least one valid swap exists on the grid.
  static bool hasValidMoves(GameGrid grid) {
    return findHint(grid) != null;
  }

  // ──────────────────────────────────────────────
  // 3. reshuffle
  // ──────────────────────────────────────────────

  /// Reshuffles all movable jellies on the grid so that at least one valid
  /// move exists and no immediate 3-matches are formed.
  static bool reshuffle(GameGrid grid, List<JellyType> availableTypes) {
    final positions = <Position>[];
    final jellies = <(JellyType?, SpecialType)>[];

    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.get(r, c);
        if (cell.hasJelly && cell.canSwap) {
          positions.add(Position(r, c));
          jellies.add((cell.jellyType, cell.specialType));
        }
      }
    }

    if (positions.length < 3) return false;

    for (int attempt = 0; attempt < 50; attempt++) {
      jellies.shuffle();
      for (int i = 0; i < positions.length; i++) {
        final pos = positions[i];
        final (jelly, special) = jellies[i];
        final cell = grid.get(pos.row, pos.col);
        grid.set(
          pos.row,
          pos.col,
          cell.copyWith(jellyType: jelly, specialType: special),
        );
      }

      final snapshot = grid.snapshot();
      final hasImmediateMatches = MatchEngine.findMatches(snapshot).isNotEmpty;
      final hasMoves = hasValidMoves(grid);

      if (!hasImmediateMatches && hasMoves) {
        grid.bumpVersion();
        return true;
      }
    }

    // Fallback: Ensure no immediate matches and guarantee moves
    MatchEngine.ensureNoInitialMatches(grid, availableTypes);
    grid.bumpVersion();
    return true;
  }
}

import 'dart:math';

import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/game_grid.dart';
import 'package:patpat_game/models/position.dart';

/// Handles obstacle-specific mechanics: chocolate spread, chain damage,
/// box destruction, fog dispersal, ice damage, and chocolate damage.
class ObstacleEngine {
  ObstacleEngine._();

  static final _rng = Random();

  static const _dirs = [
    Position(-1, 0),
    Position(1, 0),
    Position(0, -1),
    Position(0, 1),
  ];

  // ──────────────────────────────────────────────
  // 1. spreadChocolate
  // ──────────────────────────────────────────────

  /// Finds all chocolate cells, picks one at random, and spreads to one
  /// random adjacent cell that has a jelly (converting it to chocolate).
  ///
  /// Returns true if a spread occurred.
  static bool spreadChocolate(GameGrid grid) {
    // Collect all chocolate positions
    final chocolates = <Position>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        if (grid.get(r, c).obstacle == ObstacleType.chocolate) {
          chocolates.add(Position(r, c));
        }
      }
    }

    if (chocolates.isEmpty) return false;

    // Shuffle and try each chocolate cell
    chocolates.shuffle(_rng);
    for (final chocPos in chocolates) {
      final neighbors = <Position>[];
      for (final dir in _dirs) {
        final np = chocPos + dir;
        if (!np.isValid(grid.rows, grid.cols)) continue;
        final neighbor = grid.get(np.row, np.col);
        if (neighbor.hasJelly &&
            neighbor.obstacle != ObstacleType.chocolate &&
            !neighbor.isIceWall) {
          neighbors.add(np);
        }
      }

      if (neighbors.isNotEmpty) {
        final target = neighbors[_rng.nextInt(neighbors.length)];
        final cell = grid.get(target.row, target.col);
        grid.set(
          target.row,
          target.col,
          cell.copyWith(clearJelly: true, obstacle: ObstacleType.chocolate),
        );
        grid.bumpVersion();
        return true;
      }
    }

    return false;
  }

  // ──────────────────────────────────────────────
  // 2. damageAdjacentChains
  // ──────────────────────────────────────────────

  /// For each explosion position, check 4 neighbors for chains.
  /// chain2 -> chain1, chain1 -> none.
  ///
  /// Returns the number of chain layers damaged.
  static int damageAdjacentChains(
    GameGrid grid,
    List<Position> explosionPositions,
  ) {
    int damagedCount = 0;
    final processed = <Position>{};

    for (final pos in explosionPositions) {
      for (final dir in _dirs) {
        final np = pos + dir;
        if (!np.isValid(grid.rows, grid.cols) || processed.contains(np)) continue;
        final cell = grid.get(np.row, np.col);

        if (cell.obstacle == ObstacleType.chain2) {
          grid.set(np.row, np.col, cell.copyWith(obstacle: ObstacleType.chain1));
          damagedCount++;
          processed.add(np);
        } else if (cell.obstacle == ObstacleType.chain1) {
          grid.set(np.row, np.col, cell.copyWith(obstacle: ObstacleType.none));
          damagedCount++;
          processed.add(np);
        }
      }
    }

    if (damagedCount > 0) grid.bumpVersion();
    return damagedCount;
  }

  // ──────────────────────────────────────────────
  // 3. checkBoxes
  // ──────────────────────────────────────────────

  /// For each explosion position, check 4 neighbors for boxes.
  /// If a box is found, clear it.
  ///
  /// Returns the number of boxes destroyed.
  static int checkBoxes(
    GameGrid grid,
    List<Position> explosionPositions,
  ) {
    int destroyedCount = 0;
    final processed = <Position>{};

    for (final pos in explosionPositions) {
      for (final dir in _dirs) {
        final np = pos + dir;
        if (!np.isValid(grid.rows, grid.cols) || processed.contains(np)) continue;
        final cell = grid.get(np.row, np.col);

        if (cell.obstacle == ObstacleType.box) {
          grid.set(
            np.row,
            np.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.none),
          );
          destroyedCount++;
          processed.add(np);
        }
      }
    }

    if (destroyedCount > 0) grid.bumpVersion();
    return destroyedCount;
  }

  // ──────────────────────────────────────────────
  // 4. damageAdjacentChocolates
  // ──────────────────────────────────────────────

  /// For each explosion position, check 4 neighbors for chocolate.
  /// Clear any chocolate found.
  ///
  /// Returns the number of chocolates destroyed.
  static int damageAdjacentChocolates(
    GameGrid grid,
    List<Position> explosionPositions,
  ) {
    int destroyedCount = 0;
    final processed = <Position>{};

    for (final pos in explosionPositions) {
      for (final dir in _dirs) {
        final np = pos + dir;
        if (!np.isValid(grid.rows, grid.cols) || processed.contains(np)) continue;
        final cell = grid.get(np.row, np.col);

        if (cell.obstacle == ObstacleType.chocolate) {
          grid.set(
            np.row,
            np.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.none),
          );
          destroyedCount++;
          processed.add(np);
        }
      }
    }

    if (destroyedCount > 0) grid.bumpVersion();
    return destroyedCount;
  }

  // ──────────────────────────────────────────────
  // 5. damageAdjacentFog
  // ──────────────────────────────────────────────

  /// For each explosion position, check 4 neighbors for fog.
  /// Disperses any fog found.
  ///
  /// Returns the number of fog tiles cleared.
  static int damageAdjacentFog(
    GameGrid grid,
    List<Position> explosionPositions,
  ) {
    int clearedCount = 0;
    final processed = <Position>{};

    for (final pos in explosionPositions) {
      for (final dir in _dirs) {
        final np = pos + dir;
        if (!np.isValid(grid.rows, grid.cols) || processed.contains(np)) continue;
        final cell = grid.get(np.row, np.col);

        if (cell.obstacle == ObstacleType.fog) {
          grid.set(
            np.row,
            np.col,
            cell.copyWith(obstacle: ObstacleType.none),
          );
          clearedCount++;
          processed.add(np);
        }
      }
    }

    if (clearedCount > 0) grid.bumpVersion();
    return clearedCount;
  }

  // ──────────────────────────────────────────────
  // 6. damageAdjacentIce
  // ──────────────────────────────────────────────

  /// For each explosion position, check 4 neighbors for ice underlay.
  /// Degrades ice2 -> ice1, ice1 -> none.
  ///
  /// Returns the number of ice layers broken.
  static int damageAdjacentIce(
    GameGrid grid,
    List<Position> explosionPositions,
  ) {
    int brokenCount = 0;
    final processed = <Position>{};

    for (final pos in explosionPositions) {
      for (final dir in _dirs) {
        final np = pos + dir;
        if (!np.isValid(grid.rows, grid.cols) || processed.contains(np)) continue;
        final cell = grid.get(np.row, np.col);

        if (cell.obstacle == ObstacleType.ice2) {
          grid.set(np.row, np.col, cell.copyWith(obstacle: ObstacleType.ice1));
          brokenCount++;
          processed.add(np);
        } else if (cell.obstacle == ObstacleType.ice1) {
          grid.set(np.row, np.col, cell.copyWith(obstacle: ObstacleType.none));
          brokenCount++;
          processed.add(np);
        }
      }
    }

    if (brokenCount > 0) grid.bumpVersion();
    return brokenCount;
  }
}

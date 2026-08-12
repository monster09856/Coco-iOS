import 'dart:math';

import 'package:patpat_game/models/cell.dart';
import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/game_grid.dart';
import 'package:patpat_game/models/position.dart';

/// Represents a group of matched cells on the grid.
class Match {
  final List<Position> positions;
  final JellyType jellyType;
  final MatchDirection direction;
  final MatchShape shape;

  const Match({
    required this.positions,
    required this.jellyType,
    required this.direction,
    required this.shape,
  });

  int get length => positions.length;

  @override
  String toString() =>
      'Match(${jellyType.name}, ${shape.name}, ${direction.name}, '
      'len=${positions.length})';
}

/// Represents a single jelly falling from one cell to another.
class FallMove {
  final Position from;
  final Position to;

  const FallMove({required this.from, required this.to});

  @override
  String toString() => 'Fall($from -> $to)';
}

/// Core match-3 game engine with static helper methods.
///
/// Handles match detection, gravity, fill, swap validation, and
/// match removal with special-type spawning.
class MatchEngine {
  MatchEngine._();

  static final _rng = Random();

  // ──────────────────────────────────────────────
  // 1. findMatches
  // ──────────────────────────────────────────────

  /// Scans the grid for all horizontal and vertical 3+ matches.
  ///
  /// T-shape and L-shape merges are detected when a horizontal and
  /// vertical match of the same jelly type share at least one cell.
  static List<Match> findMatches(List<List<Cell>> grid) {
    if (grid.isEmpty || grid[0].isEmpty) return [];
    final rows = grid.length;
    final cols = grid[0].length;

    final hMatches = <Match>[];
    final vMatches = <Match>[];

    // --- Horizontal scan ---
    for (int r = 0; r < rows; r++) {
      int c = 0;
      while (c < cols) {
        final cell = grid[r][c];
        if (!cell.canMatch) {
          c++;
          continue;
        }
        final type = cell.jellyType!;
        int end = c + 1;
        while (end < cols &&
            grid[r][end].canMatch &&
            grid[r][end].jellyType == type) {
          end++;
        }
        final len = end - c;
        if (len >= 3) {
          final positions = [for (int i = c; i < end; i++) Position(r, i)];
          hMatches.add(Match(
            positions: positions,
            jellyType: type,
            direction: MatchDirection.horizontal,
            shape: _shapeForLength(len),
          ));
        }
        c = end;
      }
    }

    // --- Vertical scan ---
    for (int c = 0; c < cols; c++) {
      int r = 0;
      while (r < rows) {
        final cell = grid[r][c];
        if (!cell.canMatch) {
          r++;
          continue;
        }
        final type = cell.jellyType!;
        int end = r + 1;
        while (end < rows &&
            grid[end][c].canMatch &&
            grid[end][c].jellyType == type) {
          end++;
        }
        final len = end - r;
        if (len >= 3) {
          final positions = [for (int i = r; i < end; i++) Position(i, c)];
          vMatches.add(Match(
            positions: positions,
            jellyType: type,
            direction: MatchDirection.vertical,
            shape: _shapeForLength(len),
          ));
        }
        r = end;
      }
    }

    // --- Merge T / L shapes ---
    return _mergeIntersecting(hMatches, vMatches);
  }

  /// Merges intersecting horizontal + vertical matches of the same
  /// jelly type into T-shape or L-shape matches. Unmerged matches
  /// are returned as-is.
  static List<Match> _mergeIntersecting(
    List<Match> hMatches,
    List<Match> vMatches,
  ) {
    final usedH = List.filled(hMatches.length, false);
    final usedV = List.filled(vMatches.length, false);
    final result = <Match>[];

    for (int hi = 0; hi < hMatches.length; hi++) {
      for (int vi = 0; vi < vMatches.length; vi++) {
        final h = hMatches[hi];
        final v = vMatches[vi];
        if (h.jellyType != v.jellyType) continue;

        final hSet = h.positions.toSet();
        final vSet = v.positions.toSet();
        if (hSet.intersection(vSet).isEmpty) continue;

        // They intersect with same type → merge
        final merged = {...hSet, ...vSet}.toList();
        final totalLen = merged.length;
        final shape = totalLen >= 6 ? MatchShape.lShape : MatchShape.tShape;

        result.add(Match(
          positions: merged,
          jellyType: h.jellyType,
          direction: MatchDirection.horizontal, // dominant direction
          shape: shape,
        ));
        usedH[hi] = true;
        usedV[vi] = true;
      }
    }

    for (int i = 0; i < hMatches.length; i++) {
      if (!usedH[i]) result.add(hMatches[i]);
    }
    for (int i = 0; i < vMatches.length; i++) {
      if (!usedV[i]) result.add(vMatches[i]);
    }

    return result;
  }

  static MatchShape _shapeForLength(int len) {
    if (len >= 5) return MatchShape.line5;
    if (len == 4) return MatchShape.line4;
    return MatchShape.line3;
  }

  // ──────────────────────────────────────────────
  // 2. determineSpecialType
  // ──────────────────────────────────────────────

  /// Determines which special type (if any) a match should produce.
  static SpecialType determineSpecialType(
    Match match, [
    Position? swapPosition,
  ]) {
    switch (match.shape) {
      case MatchShape.line3:
        return SpecialType.none;
      case MatchShape.line4:
        // 4-match → ROCKET (line clear, perpendicular to match direction).
        return match.direction == MatchDirection.horizontal
            ? SpecialType.rocketVertical
            : SpecialType.rocketHorizontal;
      case MatchShape.line5:
        // 5-match → RAINBOW (color blast — wipes one whole color).
        return SpecialType.rainbow;
      case MatchShape.tShape:
        return match.positions.length >= 6
            ? SpecialType.lightning
            : SpecialType.bomb;
      case MatchShape.lShape:
        return match.positions.length >= 6
            ? SpecialType.lightning
            : SpecialType.bomb;
    }
  }

  // ──────────────────────────────────────────────
  // 3. applyGravity
  // ──────────────────────────────────────────────

  /// Makes jellies fall downward into empty cells.
  ///
  /// * IceWall blocks gravity — pieces above an iceWall stay put.
  /// * Bubbles float UP toward row 0.
  /// * Chained cells don't move.
  ///
  /// Returns a list of [FallMove]s describing each movement.
  static List<FallMove> applyGravity(GameGrid grid) {
    final moves = <FallMove>[];

    for (int c = 0; c < grid.cols; c++) {
      // Split column into segments between iceWalls
      final segments = _columnSegments(grid, c);
      for (final seg in segments) {
        _applyGravityToSegment(grid, c, seg, moves);
      }
    }

    // Bubble float-up pass (toward row 0)
    for (int c = 0; c < grid.cols; c++) {
      _applyBubbleFloat(grid, c, moves);
    }

    if (moves.isNotEmpty) grid.bumpVersion();
    return moves;
  }

  /// Returns row-range segments for a column, split by iceWalls.
  /// Each segment is a (startRow, endRow) inclusive range.
  static List<(int, int)> _columnSegments(GameGrid grid, int col) {
    final segments = <(int, int)>[];
    int start = 0;
    for (int r = 0; r < grid.rows; r++) {
      if (grid.get(r, col).isIceWall) {
        if (r > start) segments.add((start, r - 1));
        start = r + 1;
      }
    }
    if (start < grid.rows) segments.add((start, grid.rows - 1));
    return segments;
  }

  /// Standard downward gravity within a segment.
  static void _applyGravityToSegment(
    GameGrid grid,
    int col,
    (int, int) segment,
    List<FallMove> moves,
  ) {
    final (top, bottom) = segment;

    // Work from bottom up: for each empty spot, pull the nearest
    // jelly above it downward.
    int writeRow = bottom;
    for (int r = bottom; r >= top; r--) {
      final cell = grid.get(r, col);
      if (cell.isChained) {
        // Chained cells don't move — they act as fixed anchors but
        // don't block other pieces from falling past them.
        // Reset write cursor to just above this chained cell.
        writeRow = r - 1;
        continue;
      }
      if (cell.hasJelly && cell.obstacle != ObstacleType.iceWall) {
        if (r != writeRow) {
          final target = grid.get(writeRow, col);
          // Only move into truly empty cells
          if (!target.hasJelly &&
              !target.isIceWall &&
              !target.isChained) {
            grid.set(
              writeRow,
              col,
              target.copyWith(
                jellyType: cell.jellyType,
                specialType: cell.specialType,
              ),
            );
            grid.set(r, col, cell.copyWith(clearJelly: true, specialType: SpecialType.none));
            moves.add(FallMove(
              from: Position(r, col),
              to: Position(writeRow, col),
            ));
          }
        }
        writeRow--;
      }
    }
  }

  /// Bubbles float upward (toward row 0).
  static void _applyBubbleFloat(
    GameGrid grid,
    int col,
    List<FallMove> moves,
  ) {
    for (int r = 1; r < grid.rows; r++) {
      final cell = grid.get(r, col);
      if (!cell.isBubble || !cell.hasJelly) continue;

      // Find topmost empty row above
      int target = r;
      for (int t = r - 1; t >= 0; t--) {
        final above = grid.get(t, col);
        if (above.isIceWall) break;
        if (!above.hasJelly && above.obstacle == ObstacleType.none) {
          target = t;
        } else {
          break;
        }
      }
      if (target == r) continue;

      final dest = grid.get(target, col);
      grid.set(
        target,
        col,
        dest.copyWith(
          jellyType: cell.jellyType,
          specialType: cell.specialType,
          obstacle: ObstacleType.bubble,
        ),
      );
      grid.set(r, col, cell.copyWith(clearJelly: true, obstacle: ObstacleType.none));
      moves.add(FallMove(from: Position(r, col), to: Position(target, col)));
    }
  }

  // ──────────────────────────────────────────────
  // 4. fillEmpty
  // ──────────────────────────────────────────────

  /// Fills empty cells (no jelly, no obstacle) with random jelly types
  /// that don't create immediate 3-matches.
  static List<Position> fillEmpty(
    GameGrid grid,
    List<JellyType> availableTypes,
  ) {
    final filled = <Position>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.get(r, c);
        if (cell.isEmpty) {
          final type = _pickNonMatchingType(grid, r, c, availableTypes);
          grid.set(r, c, cell.copyWith(jellyType: type));
          filled.add(Position(r, c));
        }
      }
    }
    if (filled.isNotEmpty) grid.bumpVersion();
    return filled;
  }

  /// Picks a jelly type that won't form an immediate 3-match when placed
  /// at (row, col). Shuffles available types and tries each one.
  static JellyType _pickNonMatchingType(
    GameGrid grid,
    int row,
    int col,
    List<JellyType> availableTypes,
  ) {
    final shuffled = List<JellyType>.from(availableTypes)..shuffle(_rng);

    for (final type in shuffled) {
      if (!_wouldCreateMatch(grid, row, col, type)) {
        return type;
      }
    }
    // Fallback — every type creates a match, just use the first.
    return shuffled.first;
  }

  /// Checks if placing [type] at (row, col) would create a horizontal
  /// or vertical 3-match by checking neighbors.
  static bool _wouldCreateMatch(
    GameGrid grid,
    int row,
    int col,
    JellyType type,
  ) {
    // Check 2 left
    if (col >= 2 &&
        _cellTypeAt(grid, row, col - 1) == type &&
        _cellTypeAt(grid, row, col - 2) == type) {
      return true;
    }
    // Check 2 above
    if (row >= 2 &&
        _cellTypeAt(grid, row - 1, col) == type &&
        _cellTypeAt(grid, row - 2, col) == type) {
      return true;
    }
    // Check 1 left + 1 right
    if (col >= 1 &&
        col < grid.cols - 1 &&
        _cellTypeAt(grid, row, col - 1) == type &&
        _cellTypeAt(grid, row, col + 1) == type) {
      return true;
    }
    // Check 1 above + 1 below
    if (row >= 1 &&
        row < grid.rows - 1 &&
        _cellTypeAt(grid, row - 1, col) == type &&
        _cellTypeAt(grid, row + 1, col) == type) {
      return true;
    }
    return false;
  }

  static JellyType? _cellTypeAt(GameGrid grid, int r, int c) {
    if (r < 0 || r >= grid.rows || c < 0 || c >= grid.cols) return null;
    return grid.get(r, c).jellyType;
  }

  // ──────────────────────────────────────────────
  // 5. swap
  // ──────────────────────────────────────────────

  /// Exchanges jellyType and specialType between two cells.
  /// Obstacles remain at their original positions.
  static void swap(GameGrid grid, Position pos1, Position pos2) {
    final c1 = grid.get(pos1.row, pos1.col);
    final c2 = grid.get(pos2.row, pos2.col);

    grid.set(
      pos1.row,
      pos1.col,
      c1.copyWith(jellyType: c2.jellyType, specialType: c2.specialType),
    );
    grid.set(
      pos2.row,
      pos2.col,
      c2.copyWith(jellyType: c1.jellyType, specialType: c1.specialType),
    );
    grid.bumpVersion();
  }

  // ──────────────────────────────────────────────
  // 6. isValidSwap
  // ──────────────────────────────────────────────

  /// Returns true if swapping [pos1] and [pos2] would produce at least
  /// one match or if either piece is a special. Rejects non-swappable cells.
  static bool isValidSwap(GameGrid grid, Position pos1, Position pos2) {
    final c1 = grid.get(pos1.row, pos1.col);
    final c2 = grid.get(pos2.row, pos2.col);

    if (!c1.canSwap || !c2.canSwap) return false;

    // Swapping any special jelly is always a valid move
    if (c1.specialType != SpecialType.none ||
        c2.specialType != SpecialType.none) {
      return true;
    }

    // Temporarily swap
    swap(grid, pos1, pos2);

    final snapshot = grid.snapshot();
    final matches = findMatches(snapshot);

    // Check if either position is in any match
    final hasMatch = matches.any((m) =>
        m.positions.contains(pos1) || m.positions.contains(pos2));

    // Swap back
    swap(grid, pos1, pos2);

    return hasMatch;
  }

  // ──────────────────────────────────────────────
  // 7. removeMatches
  // ──────────────────────────────────────────────

  /// Removes matched cells and handles obstacle layers.
  ///
  /// * ice2 → ice1 (jelly cleared, ice downgrades)
  /// * ice1 / fog / honey / chains → none (jelly cleared)
  /// * iceWall / portal → preserved (not cleared)
  ///
  /// If the match produces a special type, it spawns at [swapPosition]
  /// (if it's part of the match), otherwise at the first match position.
  static void removeMatches(
    GameGrid grid,
    List<Match> matches, [
    Position? swapPosition,
  ]) {
    for (final match in matches) {
      final special = determineSpecialType(match, swapPosition);

      // Determine spawn position for special
      Position spawnPos = match.positions.first;
      if (swapPosition != null && match.positions.contains(swapPosition)) {
        spawnPos = swapPosition;
      }

      for (final pos in match.positions) {
        final cell = grid.get(pos.row, pos.col);

        // Handle chains: matching breaks the chain
        if (cell.obstacle == ObstacleType.chain2) {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.chain1, specialType: SpecialType.none),
          );
          continue;
        }
        if (cell.obstacle == ObstacleType.chain1) {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.none, specialType: SpecialType.none),
          );
          continue;
        }

        // Handle ice underlay: matching degrades ice and clears jelly so pieces fall
        if (cell.obstacle == ObstacleType.ice2) {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.ice1, specialType: SpecialType.none),
          );
          continue;
        }
        if (cell.obstacle == ObstacleType.ice1 ||
            cell.obstacle == ObstacleType.fog ||
            cell.obstacle == ObstacleType.honey) {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(clearJelly: true, obstacle: ObstacleType.none, specialType: SpecialType.none),
          );
          continue;
        }

        // Don't clear iceWall or portal
        if (cell.isIceWall || cell.isPortal) continue;

        // Spawn position gets the special type
        if (pos == spawnPos && special != SpecialType.none) {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(
              specialType: special,
              obstacle: ObstacleType.none,
            ),
          );
        } else {
          grid.set(
            pos.row,
            pos.col,
            cell.copyWith(clearJelly: true, specialType: SpecialType.none),
          );
        }
      }
    }
    grid.bumpVersion();
  }

  // ──────────────────────────────────────────────
  // 7b. getSpawnPositions
  // ──────────────────────────────────────────────

  /// Returns the set of positions where specials will be spawned for the
  /// given matches, WITHOUT modifying the grid. Used by the game controller
  /// to exclude these positions from the destroy animation so the spawned
  /// special remains visible.
  static Set<Position> getSpawnPositions(
    List<Match> matches, [
    Position? swapPosition,
  ]) {
    final spawns = <Position>{};
    for (final match in matches) {
      final special = determineSpecialType(match, swapPosition);
      if (special == SpecialType.none) continue;

      Position spawnPos = match.positions.first;
      if (swapPosition != null && match.positions.contains(swapPosition)) {
        spawnPos = swapPosition;
      }

      // Only count if the spawn position won't be blocked by an obstacle
      spawns.add(spawnPos);
    }
    return spawns;
  }

  // ──────────────────────────────────────────────
  // 8. ensureNoInitialMatches
  // ──────────────────────────────────────────────

  /// Repeatedly replaces matched cells until no 3-matches remain.
  /// Safety cap of 50 iterations to prevent infinite loops.
  static void ensureNoInitialMatches(
    GameGrid grid,
    List<JellyType> availableTypes,
  ) {
    for (int iteration = 0; iteration < 50; iteration++) {
      final matches = findMatches(grid.snapshot());
      if (matches.isEmpty) return;

      for (final match in matches) {
        for (final pos in match.positions) {
          final cell = grid.get(pos.row, pos.col);
          if (!cell.hasJelly) continue;
          final newType =
              _pickNonMatchingType(grid, pos.row, pos.col, availableTypes);
          grid.set(pos.row, pos.col, cell.copyWith(jellyType: newType));
        }
      }
    }
  }
}

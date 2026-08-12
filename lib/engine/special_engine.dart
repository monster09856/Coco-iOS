import 'dart:math';

import 'package:patpat_game/models/enums.dart';
import 'package:patpat_game/models/game_grid.dart';
import 'package:patpat_game/models/position.dart';

/// Represents a visual explosion at a position (for animation).
class ExplosionEffect {
  final Position position;
  final JellyType? jellyType;
  const ExplosionEffect(this.position, this.jellyType);
}

/// Handles activation of special jellies and their combos.
class SpecialEngine {
  SpecialEngine._();

  static final _rng = Random();

  // ──────────────────────────────────────────────
  // activateSpecial
  // ──────────────────────────────────────────────

  /// Activates a single special jelly at [pos].
  ///
  /// [targetColor] is used by rainbow — if null, uses the cell's own jellyType.
  static List<ExplosionEffect> activateSpecial(
    GameGrid grid,
    Position pos,
    JellyType? targetColor,
  ) {
    final cell = grid.get(pos.row, pos.col);
    final special = cell.specialType;

    switch (special) {
      case SpecialType.rocketHorizontal:
        return _activateRocketHorizontal(grid, pos);
      case SpecialType.rocketVertical:
        return _activateRocketVertical(grid, pos);
      case SpecialType.bomb:
        return _activateBomb(grid, pos, 3);
      case SpecialType.rainbow:
        final color = targetColor ?? cell.jellyType;
        return _activateRainbow(grid, pos, color);
      case SpecialType.lightning:
        return _activateLightning(grid, pos);
      case SpecialType.none:
        return [];
    }
  }

  // ──────────────────────────────────────────────
  // activateSpecialCombo
  // ──────────────────────────────────────────────

  /// Activates a combo between two special jellies.
  static List<ExplosionEffect> activateSpecialCombo(
    GameGrid grid,
    Position pos1,
    Position pos2,
  ) {
    final c1 = grid.get(pos1.row, pos1.col);
    final c2 = grid.get(pos2.row, pos2.col);
    final s1 = c1.specialType;
    final s2 = c2.specialType;

    // 1. Rainbow + Rainbow: Clear entire board
    if (s1 == SpecialType.rainbow && s2 == SpecialType.rainbow) {
      return _clearEntireBoard(grid);
    }

    // 2. Bomb + Bomb: 5x5 massive explosion
    if (s1 == SpecialType.bomb && s2 == SpecialType.bomb) {
      return _activateBomb(grid, pos1, 5);
    }

    // 3. Rocket + Rocket: Cross laser (full row + full col)
    if (_isRocket(s1) && _isRocket(s2)) {
      return _activateCross(grid, pos1);
    }

    // 4. Rocket + Bomb: 3 rows + 3 cols mega cross
    if ((_isRocket(s1) && s2 == SpecialType.bomb) ||
        (s1 == SpecialType.bomb && _isRocket(s2))) {
      final center = _isRocket(s1) ? pos1 : pos2;
      return _activateWideCross(grid, center);
    }

    // 5. Rainbow + Rocket: Transform all jellies of target color into Rockets and fire them!
    if ((s1 == SpecialType.rainbow && _isRocket(s2)) ||
        (_isRocket(s1) && s2 == SpecialType.rainbow)) {
      final rainbowPos = s1 == SpecialType.rainbow ? pos1 : pos2;
      final rocketCell = s1 == SpecialType.rainbow ? c2 : c1;
      final targetColor = rocketCell.jellyType ?? _pickRandomBoardColor(grid);
      _clearCell(grid, pos1);
      _clearCell(grid, pos2);
      return _activateRainbowRocketCombo(grid, rainbowPos, targetColor);
    }

    // 6. Rainbow + Bomb: Transform all jellies of target color into Bombs and detonate them!
    if ((s1 == SpecialType.rainbow && s2 == SpecialType.bomb) ||
        (s1 == SpecialType.bomb && s2 == SpecialType.rainbow)) {
      final rainbowPos = s1 == SpecialType.rainbow ? pos1 : pos2;
      final bombCell = s1 == SpecialType.rainbow ? c2 : c1;
      final targetColor = bombCell.jellyType ?? _pickRandomBoardColor(grid);
      _clearCell(grid, pos1);
      _clearCell(grid, pos2);
      return _activateRainbowBombCombo(grid, rainbowPos, targetColor);
    }

    // 7. Rainbow + Regular Jelly (or any other piece)
    if (s1 == SpecialType.rainbow || s2 == SpecialType.rainbow) {
      final nonRainbowCell = s1 == SpecialType.rainbow ? c2 : c1;
      final rainbowPos = s1 == SpecialType.rainbow ? pos1 : pos2;
      final otherPos = s1 == SpecialType.rainbow ? pos2 : pos1;
      final color = nonRainbowCell.jellyType ?? _pickRandomBoardColor(grid);
      _clearCell(grid, otherPos);
      return _activateRainbow(grid, rainbowPos, color);
    }

    // Fallback: activate each separately
    final effects = <ExplosionEffect>[];
    effects.addAll(activateSpecial(grid, pos1, null));
    effects.addAll(activateSpecial(grid, pos2, null));
    return effects;
  }

  static JellyType _pickRandomBoardColor(GameGrid grid) {
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.get(r, c);
        if (cell.jellyType != null) return cell.jellyType!;
      }
    }
    return JellyType.purple;
  }

  /// Rainbow + Rocket: Transforms all jellies of [color] into rockets and fires them.
  static List<ExplosionEffect> _activateRainbowRocketCombo(
    GameGrid grid,
    Position rainbowPos,
    JellyType color,
  ) {
    final rocketPositions = <Position>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.get(r, c);
        if (cell.jellyType == color && !cell.isIceWall) {
          rocketPositions.add(Position(r, c));
        }
      }
    }

    final effects = <ExplosionEffect>[];
    bool horizontal = true;
    for (final pos in rocketPositions) {
      if (horizontal) {
        effects.addAll(_activateRocketHorizontal(grid, pos));
      } else {
        effects.addAll(_activateRocketVertical(grid, pos));
      }
      horizontal = !horizontal;
    }
    grid.bumpVersion();
    return effects;
  }

  /// Rainbow + Bomb: Transforms all jellies of [color] into bombs and detonates them.
  static List<ExplosionEffect> _activateRainbowBombCombo(
    GameGrid grid,
    Position rainbowPos,
    JellyType color,
  ) {
    final bombPositions = <Position>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.get(r, c);
        if (cell.jellyType == color && !cell.isIceWall) {
          bombPositions.add(Position(r, c));
        }
      }
    }

    final effects = <ExplosionEffect>[];
    for (final pos in bombPositions) {
      effects.addAll(_activateBomb(grid, pos, 3));
    }
    grid.bumpVersion();
    return effects;
  }

  // ──────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────

  static bool _isRocket(SpecialType s) =>
      s == SpecialType.rocketHorizontal || s == SpecialType.rocketVertical;

  /// Clears a cell safely, respecting obstacle rules:
  /// - Never clears iceWall
  /// - Degrades ice2 -> ice1
  /// - Preserves portal obstacle (clears jelly only)
  /// - Clears everything else
  static ExplosionEffect? _clearCell(GameGrid grid, Position pos) {
    if (!pos.isValid(grid.rows, grid.cols)) return null;

    final cell = grid.get(pos.row, pos.col);

    // Never clear iceWall
    if (cell.isIceWall) return null;

    // Degrade ice2 -> ice1
    if (cell.obstacle == ObstacleType.ice2) {
      grid.set(
        pos.row,
        pos.col,
        cell.copyWith(obstacle: ObstacleType.ice1),
      );
      return ExplosionEffect(pos, cell.jellyType);
    }

    // Portal: clear jelly but keep portal obstacle
    if (cell.isPortal) {
      grid.set(
        pos.row,
        pos.col,
        cell.copyWith(clearJelly: true, specialType: SpecialType.none),
      );
      return ExplosionEffect(pos, cell.jellyType);
    }

    // Everything else: clear jelly + obstacle
    if (cell.hasJelly || cell.obstacle != ObstacleType.none) {
      final jellyType = cell.jellyType;
      grid.set(
        pos.row,
        pos.col,
        cell.copyWith(
          clearJelly: true,
          specialType: SpecialType.none,
          obstacle: ObstacleType.none,
        ),
      );
      return ExplosionEffect(pos, jellyType);
    }

    return null;
  }

  /// Rocket horizontal: clear entire row.
  static List<ExplosionEffect> _activateRocketHorizontal(
    GameGrid grid,
    Position pos,
  ) {
    final effects = <ExplosionEffect>[];
    for (int c = 0; c < grid.cols; c++) {
      final effect = _clearCell(grid, Position(pos.row, c));
      if (effect != null) effects.add(effect);
    }
    grid.bumpVersion();
    return effects;
  }

  /// Rocket vertical: clear entire column.
  static List<ExplosionEffect> _activateRocketVertical(
    GameGrid grid,
    Position pos,
  ) {
    final effects = <ExplosionEffect>[];
    for (int r = 0; r < grid.rows; r++) {
      final effect = _clearCell(grid, Position(r, pos.col));
      if (effect != null) effects.add(effect);
    }
    grid.bumpVersion();
    return effects;
  }

  /// Bomb: clear NxN area around position.
  static List<ExplosionEffect> _activateBomb(
    GameGrid grid,
    Position pos,
    int size,
  ) {
    final effects = <ExplosionEffect>[];
    final half = size ~/ 2;
    for (int r = pos.row - half; r <= pos.row + half; r++) {
      for (int c = pos.col - half; c <= pos.col + half; c++) {
        final p = Position(r, c);
        if (!p.isValid(grid.rows, grid.cols)) continue;
        final effect = _clearCell(grid, p);
        if (effect != null) effects.add(effect);
      }
    }
    grid.bumpVersion();
    return effects;
  }

  /// Rainbow: clear all cells matching [color].
  static List<ExplosionEffect> _activateRainbow(
    GameGrid grid,
    Position pos,
    JellyType? color,
  ) {
    final effects = <ExplosionEffect>[];

    // Clear the rainbow cell itself
    final selfEffect = _clearCell(grid, pos);
    if (selfEffect != null) effects.add(selfEffect);

    if (color == null) {
      grid.bumpVersion();
      return effects;
    }

    // Clear all cells matching color
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final p = Position(r, c);
        if (p == pos) continue; // already cleared
        final cell = grid.get(r, c);
        if (cell.jellyType == color) {
          final effect = _clearCell(grid, p);
          if (effect != null) effects.add(effect);
        }
      }
    }
    grid.bumpVersion();
    return effects;
  }

  /// Lightning: clear self + 8 random other cells with jellies.
  static List<ExplosionEffect> _activateLightning(
    GameGrid grid,
    Position pos,
  ) {
    final effects = <ExplosionEffect>[];

    // Clear self
    final selfEffect = _clearCell(grid, pos);
    if (selfEffect != null) effects.add(selfEffect);

    // Collect all cells with jellies (excluding self)
    final candidates = <Position>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final p = Position(r, c);
        if (p == pos) continue;
        final cell = grid.get(r, c);
        if (cell.hasJelly && !cell.isIceWall) {
          candidates.add(p);
        }
      }
    }

    // Pick up to 8 random targets
    candidates.shuffle(_rng);
    final targetCount = candidates.length < 8 ? candidates.length : 8;
    for (int i = 0; i < targetCount; i++) {
      final effect = _clearCell(grid, candidates[i]);
      if (effect != null) effects.add(effect);
    }

    grid.bumpVersion();
    return effects;
  }

  /// Clear entire board (rainbow + rainbow combo).
  static List<ExplosionEffect> _clearEntireBoard(GameGrid grid) {
    final effects = <ExplosionEffect>[];
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final effect = _clearCell(grid, Position(r, c));
        if (effect != null) effects.add(effect);
      }
    }
    grid.bumpVersion();
    return effects;
  }

  /// Cross: full row + full column (rocket + rocket combo).
  static List<ExplosionEffect> _activateCross(
    GameGrid grid,
    Position pos,
  ) {
    final effects = <ExplosionEffect>[];
    // Full row
    for (int c = 0; c < grid.cols; c++) {
      final effect = _clearCell(grid, Position(pos.row, c));
      if (effect != null) effects.add(effect);
    }
    // Full column (skip intersection to avoid double-clearing)
    for (int r = 0; r < grid.rows; r++) {
      if (r == pos.row) continue;
      final effect = _clearCell(grid, Position(r, pos.col));
      if (effect != null) effects.add(effect);
    }
    grid.bumpVersion();
    return effects;
  }

  /// Wide cross: 3 rows + 3 cols (rocket + bomb combo).
  static List<ExplosionEffect> _activateWideCross(
    GameGrid grid,
    Position pos,
  ) {
    final effects = <ExplosionEffect>[];
    final cleared = <Position>{};

    // 3 rows centered on pos.row
    for (int dr = -1; dr <= 1; dr++) {
      final r = pos.row + dr;
      if (r < 0 || r >= grid.rows) continue;
      for (int c = 0; c < grid.cols; c++) {
        final p = Position(r, c);
        if (cleared.contains(p)) continue;
        cleared.add(p);
        final effect = _clearCell(grid, p);
        if (effect != null) effects.add(effect);
      }
    }

    // 3 cols centered on pos.col
    for (int dc = -1; dc <= 1; dc++) {
      final c = pos.col + dc;
      if (c < 0 || c >= grid.cols) continue;
      for (int r = 0; r < grid.rows; r++) {
        final p = Position(r, c);
        if (cleared.contains(p)) continue;
        cleared.add(p);
        final effect = _clearCell(grid, p);
        if (effect != null) effects.add(effect);
      }
    }

    grid.bumpVersion();
    return effects;
  }
}

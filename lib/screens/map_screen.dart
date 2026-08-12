import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:patpat_game/audio/sound_manager.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/models/player_progress.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/screens/daily_reward_screen.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/level_start_popup.dart';
import 'package:patpat_game/widgets/tropical/island_bottom_nav.dart';
import 'package:patpat_game/widgets/tropical/island_top_bar.dart';

/// Grand Island Map Screen — Ultra-polished Candy Crush / Royal Match style
/// level journey through 12 tropical islands with 3D jewel nodes, glowing trails,
/// dynamic island backdrops, and animated Coco mascot.
class MapScreen extends ConsumerStatefulWidget {
  final GameRegion? initialRegion;
  const MapScreen({super.key, this.initialRegion});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  late GameRegion _selectedRegion;
  int? _showLevelStartPopupFor;
  late final ScrollController _scrollCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _sparkleCtrl;
  late final AnimationController _waveCtrl;

  // Path layout geometry
  static const double _topPad = 220; // Room for Island Boss Chest at top
  static const double _bottomPad = 120; // Room above bottom nav
  static const double _levelSpacing = 125; // Vertical distance between levels
  static const double _amplitude = 95; // Horizontal curve sway width

  @override
  void initState() {
    super.initState();
    final cur = ref.read(playerProgressProvider).currentLevel;
    _selectedRegion = widget.initialRegion ?? GameRegion.forLevel(cur);
    _scrollCtrl = ScrollController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(playerProgressProvider.notifier);
      if (notifier.isDailyRewardAvailable) {
        showDailyRewardPopup(context, ref);
      }
      _scrollToActiveLevel();
      SoundManager.instance.playLoop(SoundManager.ambienceBeach, volume: 0.25);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _sparkleCtrl.dispose();
    _waveCtrl.dispose();
    SoundManager.instance.stopLoop();
    super.dispose();
  }

  void _scrollToActiveLevel() {
    if (!_scrollCtrl.hasClients) return;
    final progress = ref.read(playerProgressProvider);
    final cur = progress.currentLevel.clamp(
      _selectedRegion.startLevel,
      _selectedRegion.endLevel,
    );
    final lvlInRegion = cur - _selectedRegion.startLevel;
    final levelCount = _selectedRegion.endLevel - _selectedRegion.startLevel + 1;
    final totalHeight = _topPad + levelCount * _levelSpacing + _bottomPad;
    final yOfLevel = totalHeight - _bottomPad - (lvlInRegion + 1) * _levelSpacing;
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxExt = _scrollCtrl.position.hasContentDimensions
        ? _scrollCtrl.position.maxScrollExtent
        : 0.0;
    final target = (yOfLevel - viewportHeight / 2 + 60).clamp(0.0, maxExt);
    _scrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  void _changeRegion(GameRegion newRegion) {
    SoundManager.instance.play(SoundManager.swap, volume: 0.7);
    setState(() => _selectedRegion = newRegion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveLevel();
    });
  }

  double _xForLevel(int indexInRegion, double width) {
    final cx = width / 2;
    // S-curve swaying horizontally
    return cx + _amplitude * math.sin(indexInRegion * 0.65);
  }

  double _yForLevel(int indexInRegion, double totalHeight) {
    // Level 1 at bottom, Level 20 at top
    return totalHeight - _bottomPad - (indexInRegion + 1) * _levelSpacing;
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(playerProgressProvider);
    final size = MediaQuery.of(context).size;
    final contentWidth = math.min(size.width, 460.0);
    final levelCount = _selectedRegion.endLevel - _selectedRegion.startLevel + 1;
    final totalHeight = _topPad + levelCount * _levelSpacing + _bottomPad;

    return Scaffold(
      backgroundColor: const Color(0xFF031926),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Island Themed HD Background
          _IslandBackdrop(region: _selectedRegion),

          // 2. Ambient Shimmer & Sparkles
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _sparkleCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _AmbientSparklePainter(_sparkleCtrl.value),
              ),
            ),
          ),

          // 3. Scrollable Winding Level Trail (Centered column)
          Positioned.fill(
            top: 130, // Below top stats & Island Selector
            bottom: 75, // Above bottom navigation bar
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    height: totalHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // A) The Golden Curved Trail
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _waveCtrl,
                            builder: (_, __) => CustomPaint(
                              painter: _GoldenTrailPainter(
                                count: levelCount,
                                xFor: (i) => _xForLevel(i, contentWidth),
                                yFor: (i) => _yForLevel(i, totalHeight),
                                shimmer: _waveCtrl.value,
                              ),
                            ),
                          ),
                        ),

                        // B) Grand Island Treasure Chest at Top (Level 20 end)
                        Positioned(
                          top: _topPad - 170,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _IslandChestBanner(
                              region: _selectedRegion,
                              pulseAnimation: _pulseCtrl,
                            ),
                          ),
                        ),

                        // C) 3D Jewel Level Nodes (1 to 20)
                        for (int i = 0; i < levelCount; i++)
                          Positioned(
                            left: _xForLevel(i, contentWidth) - 40,
                            top: _yForLevel(i, totalHeight) - 40,
                            child: _JewelLevelNode(
                              level: _selectedRegion.startLevel + i,
                              progress: progress,
                              pulseAnimation: _pulseCtrl,
                              onTap: () {
                                final lvl = _selectedRegion.startLevel + i;
                                setState(() => _showLevelStartPopupFor = lvl);
                              },
                            ),
                          ),

                        // D) Animated Coco Mascot on Current Level
                        if (progress.currentLevel >= _selectedRegion.startLevel &&
                            progress.currentLevel <= _selectedRegion.endLevel)
                          _CocoMascotMarker(
                            x: _xForLevel(
                              progress.currentLevel - _selectedRegion.startLevel,
                              contentWidth,
                            ),
                            y: _yForLevel(
                              progress.currentLevel - _selectedRegion.startLevel,
                              totalHeight,
                            ),
                            pulseAnimation: _pulseCtrl,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Top App Bar & Island Carousel Selector
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IslandTopBar(
                        stars: progress.totalStars,
                        coins: progress.coins,
                        hearts: progress.lives,
                        leading: IslandCircleButton(
                          icon: Icons.home_rounded,
                          onTap: () => context.go('/menu'),
                        ),
                        trailing: [
                          IslandCircleButton(
                            icon: Icons.casino_rounded,
                            onTap: () => context.push('/spin'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _IslandHeaderCarousel(
                        currentRegion: _selectedRegion,
                        onRegionChanged: _changeRegion,
                        onOpenIslandGrid: () => context.push('/adalar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: IslandBottomNav(
                  activeIndex: 0,
                  tabs: [
                    IslandNavTab(
                      icon: Icons.map_rounded,
                      label: 'Harita',
                      onTap: () {},
                    ),
                    IslandNavTab(
                      icon: Icons.public_rounded,
                      label: 'Adalar',
                      onTap: () => context.push('/adalar'),
                    ),
                    IslandNavTab(
                      icon: Icons.casino_rounded,
                      label: 'Çark',
                      onTap: () => context.push('/spin'),
                      isCenter: true,
                    ),
                    IslandNavTab(
                      icon: Icons.shopping_bag_rounded,
                      label: 'Mağaza',
                      onTap: () => context.push('/shop'),
                    ),
                    IslandNavTab(
                      icon: Icons.emoji_events_rounded,
                      label: 'Etkinlik',
                      onTap: () => context.push('/events'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Level Start Modal Popup
          if (_showLevelStartPopupFor != null)
            LevelStartPopup(
              level: _showLevelStartPopupFor!,
              earnedStars: progress.starsForLevel(_showLevelStartPopupFor!),
              highScore: progress.highScores[_showLevelStartPopupFor!] ?? 0,
              onPlay: () {
                final lvl = _showLevelStartPopupFor!;
                setState(() => _showLevelStartPopupFor = null);
                context.push('/game/$lvl');
              },
              onClose: () => setState(() => _showLevelStartPopupFor = null),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🏝️ _IslandBackdrop — Dynamic HD Island Scenery with Vignette
// ─────────────────────────────────────────────────────────────────────────────

class _IslandBackdrop extends StatelessWidget {
  final GameRegion region;
  const _IslandBackdrop({required this.region});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          region.backgroundAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D47A1), Color(0xFF001529)],
              ),
            ),
          ),
        ),
        // Subtle top & bottom shadow gradient for HUD readability
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCC000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xDD000000),
              ],
              stops: [0.0, 0.20, 0.80, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 👑 _IslandHeaderCarousel — Island Banner with < > Quick Flipping
// ─────────────────────────────────────────────────────────────────────────────

class _IslandHeaderCarousel extends StatelessWidget {
  final GameRegion currentRegion;
  final ValueChanged<GameRegion> onRegionChanged;
  final VoidCallback onOpenIslandGrid;

  const _IslandHeaderCarousel({
    required this.currentRegion,
    required this.onRegionChanged,
    required this.onOpenIslandGrid,
  });

  @override
  Widget build(BuildContext context) {
    final regions = GameRegion.values;
    final idx = regions.indexOf(currentRegion);
    final hasPrev = idx > 0;
    final hasNext = idx < regions.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [TT.goldShine, TT.goldBright, TT.gold, TT.goldDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(180),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: TT.gold.withAlpha(120),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2C1810), Color(0xFF1A0E0A), Color(0xFF0F0806)],
            ),
            border: Border.all(color: TT.goldShine.withAlpha(120), width: 1),
          ),
          child: Row(
            children: [
              // Previous Island Arrow
              _ArrowButton(
                icon: Icons.chevron_left_rounded,
                enabled: hasPrev,
                onTap: hasPrev ? () => onRegionChanged(regions[idx - 1]) : null,
              ),

              // Island Title & Range (Tappable to view all islands)
              Expanded(
                child: GestureDetector(
                  onTap: onOpenIslandGrid,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          currentRegion.pillAsset,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.landscape_rounded,
                            color: TT.goldShine,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${idx + 1}. ${currentRegion.displayName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Bölüm ${currentRegion.startLevel} - ${currentRegion.endLevel}',
                              style: TextStyle(
                                color: TT.goldBright.withAlpha(220),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Next Island Arrow
              _ArrowButton(
                icon: Icons.chevron_right_rounded,
                enabled: hasNext,
                onTap: hasNext ? () => onRegionChanged(regions[idx + 1]) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  colors: [TT.goldShine, TT.gold, TT.goldDeep],
                )
              : null,
          color: enabled ? null : Colors.white.withAlpha(15),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.black87 : Colors.white24,
          size: 24,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 💎 _JewelLevelNode — 3D Glossy Candy Crush Jewel Node (Level 1..240)
// ─────────────────────────────────────────────────────────────────────────────

class _JewelLevelNode extends StatelessWidget {
  final int level;
  final PlayerProgress progress;
  final AnimationController pulseAnimation;
  final VoidCallback onTap;

  const _JewelLevelNode({
    required this.level,
    required this.progress,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stars = progress.starsForLevel(level);
    final isCompleted = stars > 0;
    final isCurrent = level == progress.currentLevel;
    final isBoss = level % 20 == 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 80,
        child: AnimatedBuilder(
          animation: isCurrent ? pulseAnimation : const AlwaysStoppedAnimation(0),
          builder: (_, __) {
            final pv = isCurrent ? pulseAnimation.value : 0.0;
            final nodeSize = isCurrent ? 72.0 + pv * 4 : 64.0;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. Outer Radiant Golden Glow for Current Level
                if (isCurrent) ...[
                  Container(
                    width: nodeSize + 16,
                    height: nodeSize + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: TT.goldShine.withAlpha((150 + 100 * pv).toInt()),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. 3D Beveled Outer Golden Ring
                Container(
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isCurrent
                          ? [TT.goldShine, TT.goldBright, TT.gold, TT.goldDeep]
                          : isCompleted
                              ? [const Color(0xFF81C784), const Color(0xFF388E3C), const Color(0xFF1B5E20)]
                              : [TT.goldBright, TT.gold, TT.goldDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(180),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3.5),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isCurrent
                            ? [const Color(0xFFFF9100), const Color(0xFFFF6D00), const Color(0xFFE65100)]
                            : isCompleted
                                ? [const Color(0xFF00E676), const Color(0xFF00C853), const Color(0xFF1B5E20)]
                                : [const Color(0xFF29B6F6), const Color(0xFF0288D1), const Color(0xFF01579B)],
                      ),
                      border: Border.all(color: Colors.white.withAlpha(180), width: 1.2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Top Specular Shine
                        Positioned(
                          top: 4,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: nodeSize * 0.26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withAlpha(180),
                                  Colors.white.withAlpha(0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Center Icon / Level Number
                        if (isBoss)
                          const Icon(
                            Icons.military_tech_rounded,
                            color: Colors.white,
                            size: 32,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          )
                        else
                          Text(
                            '$level',
                            style: TextStyle(
                              fontSize: isCurrent ? 24 : 21,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 3. Stars beneath completed node
                if (isCompleted)
                  Positioned(
                    bottom: -8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (sIdx) {
                        final filled = sIdx < stars;
                        return Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 15,
                          color: filled ? TT.goldBright : Colors.white38,
                          shadows: filled
                              ? [
                                  const Shadow(color: Colors.black87, blurRadius: 3),
                                  const Shadow(color: TT.goldDeep, blurRadius: 4),
                                ]
                              : null,
                        );
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🦜 _CocoMascotMarker — Bouncing Coco on active level
// ─────────────────────────────────────────────────────────────────────────────

class _CocoMascotMarker extends StatelessWidget {
  final double x;
  final double y;
  final AnimationController pulseAnimation;

  const _CocoMascotMarker({
    required this.x,
    required this.y,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, __) {
        final bounce = math.sin(pulseAnimation.value * math.pi) * 8;
        return Positioned(
          left: x - 26,
          top: y - 76 - bounce,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [TT.goldShine, TT.goldDeep],
                  ),
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: const Text(
                  'BURADASIN!',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Image.asset(
                'assets/tropical/mascot/mascot_idle.png',
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.arrow_downward_rounded,
                  color: TT.goldShine,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎁 _IslandChestBanner — Island Boss Chest at Top of Region
// ─────────────────────────────────────────────────────────────────────────────

class _IslandChestBanner extends StatelessWidget {
  final GameRegion region;
  final AnimationController pulseAnimation;

  const _IslandChestBanner({
    required this.region,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E2723), Color(0xFF1B0000)],
        ),
        border: Border.all(color: TT.goldShine, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/tropical/decor/treasure_chest_hero.png',
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.card_giftcard_rounded,
              color: TT.goldShine,
              size: 36,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${region.displayName} Sandığı',
                  style: const TextStyle(
                    color: TT.goldShine,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Bölüm ${region.endLevel}\'yi bitir ve kazan!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🛤️ _GoldenTrailPainter — Glowing Stepping Stones & Smooth Curved Path
// ─────────────────────────────────────────────────────────────────────────────

class _GoldenTrailPainter extends CustomPainter {
  final int count;
  final double Function(int) xFor;
  final double Function(int) yFor;
  final double shimmer;

  _GoldenTrailPainter({
    required this.count,
    required this.xFor,
    required this.yFor,
    required this.shimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;

    final path = Path();
    path.moveTo(xFor(0), yFor(0));
    for (int i = 1; i < count; i++) {
      final prev = Offset(xFor(i - 1), yFor(i - 1));
      final curr = Offset(xFor(i), yFor(i));
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, mid.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(curr.dx, mid.dy, curr.dx, curr.dy);
    }

    // Outer dark shadow
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Warm wooden / golden sandy path body
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFF8D6E63), Color(0xFFFFB74D), Color(0xFF8D6E63)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Golden glowing dash stepping stones
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = TT.goldShine;

    const dashLen = 10.0;
    const gapLen = 14.0;
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = shimmer * (dashLen + gapLen);
      while (dist < m.length) {
        canvas.drawPath(m.extractPath(dist, dist + dashLen), dashPaint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoldenTrailPainter old) =>
      old.shimmer != shimmer || old.count != count;
}

// ─────────────────────────────────────────────────────────────────────────────
// ✨ _AmbientSparklePainter — Ambient sparkling gold particles
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientSparklePainter extends CustomPainter {
  final double t;
  _AmbientSparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height;
      final phase = rng.nextDouble() * 2 * math.pi;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      final r = 1.5 + rng.nextDouble() * 2.2;
      final x = bx + math.sin(t * 2 * math.pi * speed + phase) * 10;
      final y = by + math.cos(t * 2 * math.pi * speed + phase) * 8;
      final a = (70 + 90 * math.sin(t * 2 * math.pi * speed + phase)).toInt();

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = TT.goldShine.withAlpha(a.clamp(0, 220))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientSparklePainter old) => true;
}

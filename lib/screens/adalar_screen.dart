import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:patpat_game/audio/sound_manager.dart';
import 'package:patpat_game/models/level_config.dart';
import 'package:patpat_game/models/player_progress.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/tropical/island_bottom_nav.dart';
import 'package:patpat_game/widgets/tropical/island_top_bar.dart';

/// Adalar Dünyası — Ultra-luxurious Island Showcase Gallery.
/// Displays all 12 tropical islands with 3D themed cards, star progress,
/// level ranges, and instant navigation to that island's map.
class AdalarScreen extends ConsumerStatefulWidget {
  const AdalarScreen({super.key});

  @override
  ConsumerState<AdalarScreen> createState() => _AdalarScreenState();
}

class _AdalarScreenState extends ConsumerState<AdalarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _navigateToIsland(GameRegion region) {
    SoundManager.instance.play(SoundManager.special, volume: 0.7);
    context.go('/map', extra: region);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(playerProgressProvider);
    final size = MediaQuery.of(context).size;
    final contentWidth = math.min(size.width, 480.0);
    final regions = GameRegion.values;

    return Scaffold(
      backgroundColor: const Color(0xFF031926),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Deep Ocean Archipelago Backdrop
          Image.asset(
            'assets/tropical/backgrounds/world_map.png',
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
          // Dark ambient glass overlay
          Container(
            color: Colors.black.withAlpha(140),
          ),

          // 2. Main Scrollable Island Cards List
          Positioned.fill(
            top: 110,
            bottom: 75,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return _IslandCard(
                      region: region,
                      index: index,
                      progress: progress,
                      pulseAnimation: _pulseCtrl,
                      onTap: () => _navigateToIsland(region),
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. Top Stats Bar & Title
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
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.go('/map'),
                        ),
                        trailing: [
                          IslandCircleButton(
                            icon: Icons.casino_rounded,
                            onTap: () => context.push('/spin'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Grand Header Title
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [TT.goldShine, TT.gold, TT.goldDeep],
                          ),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public_rounded, color: Colors.black87, size: 18),
                            SizedBox(width: 8),
                            Text(
                              '🏝️ 12 ADALAR DÜNYASI',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Bottom Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: SizedBox(
                width: contentWidth,
                child: IslandBottomNav(
                  activeIndex: 1, // Adalar is active tab
                  tabs: [
                    IslandNavTab(
                      icon: Icons.map_rounded,
                      label: 'Harita',
                      onTap: () => context.go('/map'),
                    ),
                    IslandNavTab(
                      icon: Icons.public_rounded,
                      label: 'Adalar',
                      onTap: () {},
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 🏝️ _IslandCard — 3D Luxurious Island Showcase Card
// ─────────────────────────────────────────────────────────────────────────────

class _IslandCard extends StatelessWidget {
  final GameRegion region;
  final int index;
  final PlayerProgress progress;
  final AnimationController pulseAnimation;
  final VoidCallback onTap;

  const _IslandCard({
    required this.region,
    required this.index,
    required this.progress,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = progress.currentLevel >= region.startLevel &&
        progress.currentLevel <= region.endLevel;

    // Calculate stars collected in this region
    int regionStars = 0;
    for (int lvl = region.startLevel; lvl <= region.endLevel; lvl++) {
      regionStars += progress.starsForLevel(lvl);
    }
    const maxRegionStars = 60; // 20 levels * 3 stars

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isCurrent
                ? [TT.goldShine, TT.goldBright, TT.goldDeep]
                : [Colors.white.withAlpha(60), Colors.white.withAlpha(20)],
          ),
          border: Border.all(
            color: isCurrent ? Colors.white : Colors.white.withAlpha(70),
            width: isCurrent ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? TT.gold.withAlpha(120)
                  : Colors.black.withAlpha(140),
              blurRadius: isCurrent ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Island Background Artwork Thumbnail
              Image.asset(
                region.backgroundAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1B263B),
                ),
              ),
              // Dark vignette for crystal clear text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withAlpha(210),
                      Colors.black.withAlpha(140),
                      Colors.black.withAlpha(190),
                    ],
                  ),
                ),
              ),

              // 2. Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Island Avatar Badge
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: TT.goldShine, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          region.pillAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.landscape_rounded,
                            color: TT.goldShine,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Island Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${index + 1}. ${region.displayName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color(0xFFFF9100),
                                  ),
                                  child: const Text(
                                    'AKTİF',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Bölüm ${region.startLevel} - ${region.endLevel}',
                            style: const TextStyle(
                              color: TT.goldBright,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Star Progress Bar
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: TT.goldBright,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$regionStars / $maxRegionStars',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Go to Island Action Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [TT.goldShine, TT.gold, TT.goldDeep],
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

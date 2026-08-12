import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:patpat_game/auth/auth_manager.dart';
import 'package:patpat_game/data/cloud_sync_manager.dart';
import 'package:patpat_game/providers/auth_provider.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/tropical/island_bottom_nav.dart';
import 'package:patpat_game/widgets/tropical/island_button.dart';
import 'package:patpat_game/widgets/tropical/island_panel.dart';
import 'package:patpat_game/widgets/coco_banner_ad.dart';
import 'package:patpat_game/widgets/tropical/island_top_bar.dart';
import 'package:patpat_game/widgets/tropical/mascot_view.dart';

class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final AnimationController _logoCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);

    Future(() {
      ref.read(authProvider.notifier).checkCurrentUser();
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(playerProgressProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: TT.oceanDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero background — alchemy render with fallback
          Image.asset(
            TA.mainMenuHero,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              TA.mainMenuBg,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: TT.skyOceanGradient),
              ),
            ),
          ),

          // Bottom legibility gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                  Colors.transparent,
                  TT.oceanNight.withAlpha(180),
                  TT.oceanNight.withAlpha(240),
                ],
                stops: const [0.0, 0.18, 0.45, 0.85, 1.0],
              ),
            ),
          ),

          _FloatingDecor(controller: _floatCtrl),

          // Content column
          SafeArea(
            child: Column(
              children: [
                // Top stats bar with profile avatar (left) + settings (right)
                IslandTopBar(
                  stars: progress.totalStars,
                  coins: progress.coins,
                  hearts: progress.lives,
                  leading: IslandCircleButton(
                    icon: auth.isLoggedIn ? Icons.person : Icons.login_rounded,
                    onTap: () => auth.isLoggedIn
                        ? _showProfilePopup(context)
                        : _showLoginPopup(context),
                  ),
                  trailing: [
                    IslandCircleButton(
                      icon: Icons.settings_rounded,
                      onTap: () => _showSettingsPopup(context, ref),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Logo (text-based, animated bobbing)
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) {
                    final dy = math.sin(_logoCtrl.value * math.pi) * 4;
                    final scale = 1.0 + math.sin(_logoCtrl.value * math.pi) * 0.02;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(scale: scale, child: const _CocoLogo()),
                    );
                  },
                ),

                const Spacer(flex: 2),

                // Mascot — Coco the Parrot. Tap to make him react!
                const MascotView(
                  pose: MascotPose.idle,
                  height: 200,
                  showHalo: true,
                  interactive: true,
                ),

                const Spacer(flex: 2),

                // Primary CTA — OYNA!
                IslandButton(
                  text: 'OYNA',
                  color: IslandButtonColor.coral,
                  size: IslandButtonSize.xlarge,
                  width: 280,
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.go('/map'),
                ),

                const SizedBox(height: 10),

                // Sign-in CTA — only when NOT logged in. Keeps progress
                // safe across devices, addresses the "ilk ekranda giriş
                // butonu yok" feedback.
                if (!auth.isLoggedIn && AuthManager.instance.firebaseReady)
                  IslandButton(
                    text: 'Giriş Yap',
                    color: IslandButtonColor.lagoon,
                    size: IslandButtonSize.medium,
                    width: 220,
                    icon: Icons.login_rounded,
                    onPressed: () => _showLoginPopup(context),
                  ),

                if (!auth.isLoggedIn && AuthManager.instance.firebaseReady)
                  const SizedBox(height: 8),

                const SizedBox(height: 14),

                // Level chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [TT.driftWood, TT.driftWoodDark],
                    ),
                    border: Border.all(color: TT.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(140),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_rounded, color: TT.goldShine, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Bölüm ${progress.currentLevel}',
                        style: TT.titleSmall.copyWith(
                          color: TT.sandLight,
                          shadows: [
                            Shadow(
                              color: Colors.black.withAlpha(220),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Always-visible main menu banner (v1.1 monetization push).
                // CocoBannerAd self-disposes the underlying BannerAd and
                // collapses to a SizedBox when ads are disabled / unavailable.
                if (!(progress.removeAdsPurchased || progress.vipActive))
                  const Center(child: CocoBannerAd()),

                // Bottom nav
                IslandBottomNav(
                  activeIndex: 0,
                  tabs: [
                    IslandNavTab(
                      icon: Icons.map_rounded,
                      label: 'Harita',
                      onTap: () => context.go('/map'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(child: _LoginDialog(parentRef: ref)),
    );
  }

  void _showProfilePopup(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(child: _ProfileDialog(parentRef: ref)),
    );
  }
}

// ─── PatPat logo (typographic) ─────────────────────────────────────────────
class _CocoLogo extends StatelessWidget {
  const _CocoLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // sun glow behind logo
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    TT.goldShine.withAlpha(100),
                    Colors.transparent,
                  ],
                  radius: 0.7,
                ),
              ),
            ),
          ),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [TT.goldShine, TT.goldBright, TT.gold, TT.goldDeep],
              stops: [0.0, 0.4, 0.8, 1.0],
            ).createShader(rect),
            child: Text(
              'Coco',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
                height: 1.0,
                shadows: [
                  Shadow(color: Colors.black.withAlpha(220), blurRadius: 12, offset: const Offset(0, 6)),
                  Shadow(color: TT.coralDark, blurRadius: 4, offset: const Offset(0, 3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating decor (palm leaves + jellies) ────────────────────────────────
class _FloatingDecor extends StatelessWidget {
  final AnimationController controller;
  const _FloatingDecor({required this.controller});

  static const _items = <(String, double, double, double, double)>[
    ('jelly_orange', 0.12, 0.18, 0.5, 0.0),
    ('jelly_blue', 0.85, 0.16, 0.45, 0.25),
    ('jelly_pink', 0.08, 0.32, 0.5, 0.5),
    ('jelly_green', 0.92, 0.30, 0.45, 0.75),
    ('jelly_yellow', 0.16, 0.46, 0.4, 0.6),
    ('jelly_purple', 0.82, 0.44, 0.4, 0.15),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return IgnorePointer(
          child: Stack(
            children: _items.map((it) {
              final (asset, nx, ny, scale, phase) = it;
              final bob = math.sin((t + phase) * 2 * math.pi) * 8;
              final sway = math.cos((t + phase) * 2 * math.pi) * 4;
              final s = 60.0 * scale;
              return Positioned(
                left: size.width * nx - s / 2 + sway,
                top: size.height * ny - s / 2 + bob,
                child: Transform.rotate(
                  angle: math.sin((t + phase) * 2 * math.pi) * 0.1,
                  child: Image.asset(
                    'assets/sprites/$asset.png',
                    width: s,
                    height: s,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Login Dialog ──────────────────────────────────────────────────────────
class _LoginDialog extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _LoginDialog({required this.parentRef});

  @override
  ConsumerState<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<_LoginDialog> {
  bool _isLoading = false;
  String? _err;

  Future<void> _handleSignIn(Future<bool> Function() method) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _err = null;
    });
    final ok = await method();
    if (ok && mounted) {
      // Close immediately so the user isn't stuck behind a spinner if
      // Firestore is slow / not yet provisioned. Cloud sync runs in the
      // background — local progress is authoritative until it returns.
      Navigator.of(context).pop();
      _runBackgroundCloudSync();
    } else if (mounted) {
      // Surface the real provider error so Apple Review (and us, on TestFlight)
      // can see the failing phase + code. authProvider.lastError holds the
      // last AuthResult.error string, e.g.
      //   "Apple[apple-ui] canceled: User canceled the sign-in"
      //   "Firebase[firebase-signin] invalid-credential: ..."
      final providerErr = ref.read(authProvider).lastError;
      setState(() {
        _isLoading = false;
        _err = providerErr ?? 'Giriş başarısız oldu';
      });
    }
  }

  void _runBackgroundCloudSync() {
    () async {
      try {
        final cloud = await CloudSyncManager.instance.pull();
        if (cloud != null) {
          await widget.parentRef
              .read(playerProgressProvider.notifier)
              .mergeWithCloud(cloud);
        } else {
          final local = widget.parentRef.read(playerProgressProvider);
          await CloudSyncManager.instance.push(local);
        }
      } catch (_) {
        // Silent — local progress remains the source of truth.
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = AuthManager.instance.firebaseReady;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: IslandPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Center(
                    child: Text(
                      'Giriş Yap',
                      style: TT.titleLarge.copyWith(color: TT.goldDeep, fontSize: 24),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -10,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: TT.driftWoodDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'İlerlemeni kaydet, cihazlar arası senkronize et',
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: 2,
                style: TT.bodySmall.copyWith(height: 1.3),
              ),
              const SizedBox(height: 22),
              if (!firebaseReady)
                _FirebaseDisabledNote()
              else if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(TT.coral),
                  ),
                )
              else ...[
                _SocialBtn(
                  label: 'Google ile Giriş',
                  icon: Icons.g_mobiledata_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4285F4), Color(0xFF3367D6)],
                  ),
                  onTap: () => _handleSignIn(ref.read(authProvider.notifier).signInWithGoogle),
                ),
                if (Platform.isIOS) ...[
                  const SizedBox(height: 10),
                  _SocialBtn(
                    label: 'Apple ile Giriş',
                    icon: Icons.apple,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A1A), Colors.black],
                    ),
                    onTap: () => _handleSignIn(ref.read(authProvider.notifier).signInWithApple),
                  ),
                ],
                if (_err != null) ...[
                  const SizedBox(height: 10),
                  // Show the full diagnostic — multi-line + selectable so
                  // App Review (and we, from TestFlight) can read / copy the
                  // failing phase + provider code.
                  SelectableText(
                    _err!,
                    textAlign: TextAlign.center,
                    style: TT.bodySmall.copyWith(color: TT.danger, fontSize: 11),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FirebaseDisabledNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: TT.coralLight.withAlpha(60),
        border: Border.all(color: TT.coral.withAlpha(120)),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: TT.coral, size: 28),
          const SizedBox(height: 6),
          Text('Giriş şu an aktif değil',
              style: TT.titleSmall.copyWith(color: TT.coralDark)),
          Text('Firebase yapılandırılmamış',
              style: TT.bodySmall.copyWith(color: TT.inkMid)),
        ],
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: gradient,
          border: Border.all(color: Colors.white.withAlpha(60), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Dialog (logged in) ────────────────────────────────────────────
class _ProfileDialog extends ConsumerWidget {
  final WidgetRef parentRef;
  const _ProfileDialog({required this.parentRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: IslandPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MascotView(pose: MascotPose.happy, height: 100, bobbing: true),
              const SizedBox(height: 8),
              Text(auth.userName ?? 'Hesabım', style: TT.titleLarge.copyWith(color: TT.goldDeep)),
              if (auth.userEmail != null)
                Text(auth.userEmail!, style: TT.bodySmall),
              const SizedBox(height: 20),
              IslandButton(
                text: 'Çıkış Yap',
                color: IslandButtonColor.coral,
                size: IslandButtonSize.medium,
                fullWidth: true,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
              IslandButton(
                text: 'Kapat',
                color: IslandButtonColor.bamboo,
                size: IslandButtonSize.medium,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings Dialog ───────────────────────────────────────────────────────
void _showSettingsPopup(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => Center(child: _SettingsDialog(ref: ref)),
  );
}

class _SettingsDialog extends ConsumerWidget {
  final WidgetRef ref;
  const _SettingsDialog({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef cref) {
    final progress = cref.watch(playerProgressProvider);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: IslandPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Center(
                    child: Text(
                      'Ayarlar',
                      style: TT.titleLarge.copyWith(color: TT.goldDeep, fontSize: 24),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -10,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: TT.driftWoodDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingToggle(
                label: 'Ses',
                icon: Icons.volume_up_rounded,
                value: progress.soundEnabled,
                onChanged: (v) => cref.read(playerProgressProvider.notifier).updateSettings(sound: v),
              ),
              const SizedBox(height: 10),
              _SettingToggle(
                label: 'Müzik',
                icon: Icons.music_note_rounded,
                value: progress.musicEnabled,
                onChanged: (v) => cref.read(playerProgressProvider.notifier).updateSettings(music: v),
              ),
              const SizedBox(height: 10),
              _SettingToggle(
                label: 'Titreşim',
                icon: Icons.vibration_rounded,
                value: progress.vibrationEnabled,
                onChanged: (v) => cref.read(playerProgressProvider.notifier).updateSettings(vibration: v),
              ),
              const SizedBox(height: 14),
              // Help & Support — opens dosto.tr contact page in browser.
              // Mailto fallback if web fails (Android/iOS supports both schemes).
              _SettingsActionRow(
                label: 'Yardım & Destek',
                icon: Icons.help_outline_rounded,
                onTap: () => _openSupport(context),
              ),
              const SizedBox(height: 8),
              _SettingsActionRow(
                label: 'Öneri Gönder',
                icon: Icons.lightbulb_outline_rounded,
                onTap: () => _openSupport(context, subject: 'Coco öneri'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSupport(BuildContext context, {String? subject}) async {
    // Try dosto.tr contact page first; fall back to mailto if browser fails.
    final webUri = Uri.parse('https://dosto.tr/iletisim');
    final mailUri = Uri(
      scheme: 'mailto',
      path: 'dostocomp@gmail.com',
      queryParameters: {
        if (subject != null) 'subject': subject,
        'body': 'Coco Match-3 hakkında:\n\n',
      },
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      if (await canLaunchUrl(mailUri)) {
        await launchUrl(mailUri);
        return;
      }
    } catch (_) {}
    messenger?.showSnackBar(const SnackBar(
      backgroundColor: TT.coral,
      content: Text('Tarayıcı/e-posta açılamadı: dostocomp@gmail.com'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _SettingsActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: TT.sandLight.withAlpha(220),
          border: Border.all(color: TT.bamboo, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: TT.driftWoodDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TT.titleSmall),
            ),
            const Icon(Icons.chevron_right_rounded, color: TT.driftWoodDark, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: TT.sandLight.withAlpha(220),
        border: Border.all(color: TT.bamboo, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: TT.driftWoodDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TT.titleSmall),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: TT.palm,
            activeTrackColor: TT.palmLight,
          ),
        ],
      ),
    );
  }
}

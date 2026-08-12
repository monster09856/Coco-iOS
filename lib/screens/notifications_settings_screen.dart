import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:patpat_game/notifications/notification_manager.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/theme/tropical_theme.dart';
import 'package:patpat_game/widgets/tropical/island_panel.dart';
import 'package:patpat_game/widgets/tropical/island_scaffold.dart';
import 'package:patpat_game/widgets/tropical/island_top_bar.dart';

/// Settings screen for notifications. Master toggle + 5 sub-toggles +
/// quiet-hours info. Linked from Profile → Bildirimler.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playerProgressProvider);
    final notifier = ref.read(playerProgressProvider.notifier);

    return IslandScaffold(
      backgroundAsset: TA.profileBg,
      overlayOpacity: 0.36,
      child: SafeArea(
        child: Column(
          children: [
            IslandTopBar(
              stars: progress.totalStars,
              coins: progress.coins,
              hearts: progress.lives,
              leading: IslandCircleButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            const SizedBox(height: 8),
            // Section title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: TT.goldShine, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Bildirimler',
                    style: TT.titleLarge.copyWith(color: TT.goldShine, fontSize: 22, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Master toggle — visually emphasized
                    _MasterTile(
                      enabled: progress.notifsEnabled,
                      onChanged: (v) async {
                        if (v) {
                          // Re-asking permission when re-enabling.
                          final granted = await NotificationManager.instance.requestPermission();
                          if (!granted) return;
                        }
                        await notifier.updateNotifPrefs(master: v);
                      },
                    ),
                    const SizedBox(height: 14),
                    // Quiet hours info
                    _QuietHoursInfo(),
                    const SizedBox(height: 14),
                    // Sub-toggles
                    IslandPanel(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      child: Column(
                        children: [
                          _ToggleRow(
                            icon: Icons.favorite_rounded,
                            iconColor: TT.coral,
                            label: 'Canlar Doldu',
                            sub: 'Tüm canların yenilenince bildirim',
                            value: progress.notifsLifeFull,
                            disabled: !progress.notifsEnabled,
                            onChanged: (v) => notifier.updateNotifPrefs(lifeFull: v),
                          ),
                          const _Divider(),
                          _ToggleRow(
                            icon: Icons.egg_rounded,
                            iconColor: TT.gold,
                            label: 'Yumurta Çatlamak Üzere',
                            sub: 'Yuva slotu %80+ dolduğunda',
                            value: progress.notifsEgg,
                            disabled: !progress.notifsEnabled,
                            onChanged: (v) => notifier.updateNotifPrefs(egg: v),
                          ),
                          const _Divider(),
                          _ToggleRow(
                            icon: Icons.calendar_today_rounded,
                            iconColor: TT.palm,
                            label: 'Günlük Hatırlatma',
                            sub: 'Her gün 19:00 — Coco seni özler',
                            value: progress.notifsDaily,
                            disabled: !progress.notifsEnabled,
                            onChanged: (v) => notifier.updateNotifPrefs(daily: v),
                          ),
                          const _Divider(),
                          _ToggleRow(
                            icon: Icons.card_giftcard_rounded,
                            iconColor: TT.coralLight,
                            label: 'Günlük Ödül',
                            sub: 'Ödülün hazır olduğunda',
                            value: progress.notifsDailyReward,
                            disabled: !progress.notifsEnabled,
                            onChanged: (v) => notifier.updateNotifPrefs(dailyReward: v),
                          ),
                          const _Divider(),
                          _ToggleRow(
                            icon: Icons.celebration_rounded,
                            iconColor: TT.lagoon,
                            label: 'Kampanya / Etkinlik',
                            sub: 'Yeni özellik, sürpriz hediye, etkinlik',
                            value: progress.notifsCampaign,
                            disabled: !progress.notifsEnabled,
                            onChanged: (v) => notifier.updateNotifPrefs(campaign: v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _MasterTile({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [TT.goldShine, TT.gold, TT.goldDeep],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(160), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: TT.gold.withAlpha(120), blurRadius: 18, spreadRadius: -2),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: TT.driftPanelGradient,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled ? const [TT.palmLight, TT.palm] : [Colors.grey.shade600, Colors.grey.shade800],
                ),
              ),
              child: Icon(
                enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tüm Bildirimler',
                      style: TT.titleMedium.copyWith(color: TT.sandLight, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    enabled ? 'Açık — Coco haber verecek' : 'Kapalı — bildirim gelmiyor',
                    style: TT.bodySmall.copyWith(color: TT.sandLight.withAlpha(200)),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeTrackColor: TT.palm,
              activeColor: TT.goldShine,
              inactiveTrackColor: TT.driftWoodDark,
              inactiveThumbColor: TT.sandLight.withAlpha(160),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = disabled ? TT.driftWood.withAlpha(140) : TT.driftWoodDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(iconColor, Colors.white, 0.2)!, iconColor],
              ),
              boxShadow: disabled
                  ? null
                  : [BoxShadow(color: iconColor.withAlpha(120), blurRadius: 6, spreadRadius: -1)],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TT.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 1),
                Text(sub, style: TT.bodySmall.copyWith(color: color.withAlpha(180), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value && !disabled,
            onChanged: disabled ? null : onChanged,
            activeTrackColor: TT.palm,
            activeColor: TT.goldShine,
            inactiveTrackColor: TT.driftWood.withAlpha(180),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: TT.bamboo.withAlpha(120));
}

class _QuietHoursInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: TT.driftWoodDark.withAlpha(180),
        border: Border.all(color: TT.bamboo.withAlpha(180), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.bedtime_rounded, color: TT.goldShine, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sessiz Saat',
                  style: TT.bodyMedium.copyWith(color: TT.goldShine, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '21:00 – 09:00 arası bildirim gönderilmez. Geç saatte tetiklenen bildirimler ertesi sabaha ertelenir.',
                  style: TT.bodySmall.copyWith(color: TT.sandLight.withAlpha(220), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

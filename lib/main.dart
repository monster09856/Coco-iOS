import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:patpat_game/auth/auth_manager.dart';
import 'package:patpat_game/billing/billing_manager.dart';
import 'package:patpat_game/ads/ad_manager.dart';
import 'package:patpat_game/notifications/notification_manager.dart';
import 'package:patpat_game/notifications/fcm_manager.dart';
import 'package:patpat_game/router.dart';
import 'package:patpat_game/providers/game_providers.dart';
import 'package:patpat_game/services/cloud_time_sync.dart';
import 'package:patpat_game/widgets/achievement_unlock_toast.dart';
import 'package:patpat_game/widgets/update_banner.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      await Firebase.initializeApp();
      AuthManager.instance.firebaseReady = true;
    } catch (_) {
      AuthManager.instance.firebaseReady = false;
    }

    await CloudTimeSync.loadCached();
    if (AuthManager.instance.firebaseReady) {
      unawaited(CloudTimeSync.sync());
    }

    await NotificationManager.instance.init();
  }

  runApp(const ProviderScope(child: CocoApp()));
}

class CocoApp extends ConsumerStatefulWidget {
  const CocoApp({super.key});

  @override
  ConsumerState<CocoApp> createState() => _CocoAppState();
}

class _CocoAppState extends ConsumerState<CocoApp> {
  @override
  void initState() {
    super.initState();
    ref.read(playerProgressProvider.notifier).load();
    if (!kIsWeb) {
      _initBilling();
      _initAds();
      _initFcm();
    }
  }

  Future<void> _initFcm() async {
    if (!AuthManager.instance.firebaseReady) return;
    await FcmManager.instance.init(
      onToken: (token) async {
        await ref.read(playerProgressProvider.notifier).setFcmToken(token);
      },
    );
  }

  Future<void> _initAds() async {
    final progress = ref.read(playerProgressProvider);
    AdManager.instance.adsDisabled =
        progress.removeAdsPurchased || progress.vipActive;
    await _requestTrackingPermissionIfNeeded();
    await AdManager.instance.init();
  }

  Future<void> _requestTrackingPermissionIfNeeded() async {
    if (kIsWeb) return;
    try {
      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {
      // ATT only available on iOS 14.5+
    }
  }

  Future<void> _initBilling() async {
    await BillingManager.instance.init();
    BillingManager.instance.setDeliveryCallback((productId) {
      ref.read(playerProgressProvider.notifier).deliverIAP(productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Coco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0235),
      ),
      routerConfig: AppRouter.router,
      // Mount the global achievement unlock toast above every screen.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const AchievementUnlockToast(),
            // Update banner sits ABOVE the achievement toast so a forced
            // update modal can block all interaction.
            const UpdateBanner(),
          ],
        );
      },
    );
  }
}

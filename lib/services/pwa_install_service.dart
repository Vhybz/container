import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'pwa_install_service_stub.dart'
    if (dart.library.js_interop) 'pwa_install_service_web.dart'
    if (dart.library.html) 'pwa_install_service_web.dart';

class PwaInstallService {
  static bool canInstall() => PwaInstallServiceImpl.canInstall();

  static Future<bool> triggerPwaInstall() => PwaInstallServiceImpl.triggerPwaInstall();

  static void promptInstall() {
    PwaInstallServiceImpl.promptInstall();
  }

  static void listenToInstallStatus(void Function(bool canInstall) onChanged) {
    PwaInstallServiceImpl.listenToInstallStatus(onChanged);
  }

  static bool isIosSafari() => PwaInstallServiceImpl.isIosSafari();

  /// Checks if the user has previously dismissed the PWA install banner
  static bool isDismissed() {
    try {
      if (!Hive.isBoxOpen('app_settings')) return false;
      final box = Hive.box('app_settings');
      return box.get('pwa_banner_dismissed', defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  /// Persists banner dismissal state to local Hive storage
  static Future<void> markDismissed() async {
    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      await box.put('pwa_banner_dismissed', true);
    } catch (_) {
      //
    }
  }
}

/// Reactive Riverpod provider for PWA install state
final pwaCanInstallProvider = StateNotifierProvider<PwaInstallNotifier, bool>((ref) {
  return PwaInstallNotifier();
});

// Alias for backwards compatibility
final pwaInstallableProvider = pwaCanInstallProvider;

class PwaInstallNotifier extends StateNotifier<bool> {
  PwaInstallNotifier() : super(PwaInstallService.canInstall()) {
    PwaInstallService.listenToInstallStatus((canInstall) {
      state = canInstall;
    });
  }

  Future<bool> triggerPwaInstall() async {
    final success = await PwaInstallService.triggerPwaInstall();
    state = PwaInstallService.canInstall();
    return success;
  }

  void promptInstall() {
    triggerPwaInstall();
  }

  void dismissBanner() {
    PwaInstallService.markDismissed();
  }
}

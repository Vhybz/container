import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('checkPwaCanInstall')
external JSBoolean? checkPwaCanInstall();

@JS('promptPwaInstallation')
external JSPromise<JSBoolean>? promptPwaInstallation();

class PwaInstallServiceImpl {
  static bool canInstall() {
    try {
      final res = checkPwaCanInstall();
      return res?.toDart == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> triggerPwaInstall() async {
    try {
      final promise = promptPwaInstallation();
      if (promise != null) {
        final jsBool = await promise.toDart;
        return jsBool.toDart;
      }
    } catch (_) {
      //
    }
    return false;
  }

  static void promptInstall() {
    triggerPwaInstall();
  }

  static void listenToInstallStatus(void Function(bool canInstall) onChanged) {
    try {
      web.window.addEventListener(
        'pwa_install_ready',
        ((web.Event event) {
          onChanged(canInstall());
        }).toJS,
      );
    } catch (_) {
      //
    }
  }

  static bool isIosSafari() {
    try {
      final ua = web.window.navigator.userAgent.toLowerCase();
      final isIos = ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
      final isStandalone = web.window.matchMedia('(display-mode: standalone)').matches;
      return isIos && !isStandalone;
    } catch (_) {
      return false;
    }
  }
}

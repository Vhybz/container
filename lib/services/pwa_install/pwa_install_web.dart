import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('checkPwaCanInstall')
external JSBoolean? checkPwaCanInstall();

@JS('promptPwaInstallation')
external JSPromise<JSBoolean>? promptPwaInstallation();

class PwaInstallImpl {
  static void initPwaInstallImpl() {}

  static bool canInstallImpl() {
    try {
      final res = checkPwaCanInstall();
      return res?.toDart == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> promptInstallImpl() async {
    try {
      final promise = promptPwaInstallation();
      if (promise != null) {
        final res = await promise.toDart;
        return res.toDart;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool isIosSafariImpl() {
    try {
      final userAgent = web.window.navigator.userAgent.toLowerCase();
      final isIos = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
      final isSafari = userAgent.contains('safari') && !userAgent.contains('chrome') && !userAgent.contains('crios') && !userAgent.contains('fxios');
      return isIos && isSafari;
    } catch (_) {
      return false;
    }
  }
}

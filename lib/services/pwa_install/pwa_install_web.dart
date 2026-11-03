import 'dart:js_interop';

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
}

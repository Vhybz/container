import 'dart:html' as html;
import 'dart:js_util' as js_util;

class PwaInstallServiceImpl {
  static bool canInstall() {
    try {
      final result = js_util.callMethod(html.window, 'checkPwaCanInstall', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static void promptInstall() {
    try {
      js_util.callMethod(html.window, 'promptPwaInstallation', []);
    } catch (_) {
      //
    }
  }
}

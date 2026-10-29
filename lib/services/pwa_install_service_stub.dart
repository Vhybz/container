class PwaInstallServiceImpl {
  static bool canInstall() => false;

  static Future<bool> triggerPwaInstall() async => false;

  static void promptInstall() {
    triggerPwaInstall();
  }

  static void listenToInstallStatus(void Function(bool canInstall) onChanged) {}

  static bool isIosSafari() => false;
}

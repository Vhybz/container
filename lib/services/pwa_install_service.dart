import 'pwa_install_service_stub.dart'
    if (dart.library.html) 'pwa_install_service_web.dart';

class PwaInstallService {
  static bool canInstall() => PwaInstallServiceImpl.canInstall();
  static void promptInstall() => PwaInstallServiceImpl.promptInstall();
}

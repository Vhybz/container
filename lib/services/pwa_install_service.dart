import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import 'pwa_install/pwa_install_helper.dart';

class PwaInstallService {
  static void initialize() {
    PwaInstallImpl.initPwaInstallImpl();
  }

  static bool get canInstall => PwaInstallImpl.canInstallImpl();

  static Future<bool> promptInstall() async {
    return await PwaInstallImpl.promptInstallImpl();
  }

  /// Checks if user previously clicked "Not Now" (saved in Hive); if ready, delays 2s and displays showInstallDialog.
  static Future<void> checkAndShowPrompt(BuildContext context) async {
    if (!canInstall) return;

    try {
      final box = Hive.isBoxOpen('app_settings')
          ? Hive.box('app_settings')
          : await Hive.openBox('app_settings');
      final bool dismissed = box.get('pwa_install_dismissed', defaultValue: false);
      if (dismissed) return;
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted || !canInstall) return;

    await showInstallDialog(context);
  }

  /// Renders a modern, responsive Bottom Sheet featuring the app icon, title, description, Install button, and Not Now button.
  static Future<void> showInstallDialog(BuildContext context) async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.l),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primarySlate,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      image: const DecorationImage(
                        image: AssetImage('app_logo.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Install Container POS',
                          style: GoogleFonts.oswald(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Install for offline access, faster loading, and full-screen mode.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final box = Hive.isBoxOpen('app_settings')
                              ? Hive.box('app_settings')
                              : await Hive.openBox('app_settings');
                          await box.put('pwa_install_dismissed', true);
                        } catch (_) {}
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      ),
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await promptInstall();
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Install App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Riverpod provider for PWA install State
final pwaInstallNotifierProvider = StateNotifierProvider<PwaInstallStateNotifier, bool>((ref) {
  return PwaInstallStateNotifier();
});

class PwaInstallStateNotifier extends StateNotifier<bool> {
  PwaInstallStateNotifier() : super(PwaInstallService.canInstall);

  bool checkCanInstall() {
    state = PwaInstallService.canInstall;
    return state;
  }

  Future<bool> promptInstall() async {
    final result = await PwaInstallService.promptInstall();
    state = PwaInstallService.canInstall;
    return result;
  }
}

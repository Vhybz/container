import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pwa_install_service.dart';

class PwaInstallBanner extends ConsumerStatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  ConsumerState<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends ConsumerState<PwaInstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final canInstall = ref.watch(pwaCanInstallProvider);
    final isIosSafari = PwaInstallService.isIosSafari();

    // Do not display if dismissed or if neither native install nor iOS Safari tip applies
    if (_dismissed || (!canInstall && !isIosSafari)) {
      return const SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIosSafari ? Icons.share_rounded : (isDesktop ? Icons.desktop_windows_rounded : Icons.install_mobile_rounded),
                    color: Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Install App for Faster Access & Offline Mode',
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isIosSafari
                            ? "Tap the Share button → Select 'Add to Home Screen'"
                            : "1-Click install for desktop and mobile offline access",
                        style: TextStyle(
                          color: isIosSafari ? Colors.amberAccent : Colors.white70,
                          fontSize: 11,
                          fontWeight: isIosSafari ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canInstall && !isIosSafari) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final installed = await ref.read(pwaCanInstallProvider.notifier).triggerPwaInstall();
                      if (installed) {
                        setState(() => _dismissed = true);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      'INSTALL APP NOW',
                      style: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
                IconButton(
                  onPressed: () => setState(() => _dismissed = true),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Dismiss Banner',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

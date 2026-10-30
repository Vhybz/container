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

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Positioned(
      bottom: 16,
      left: 12,
      right: 12,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIosSafari
                            ? Icons.share_rounded
                            : (isMobile ? Icons.install_mobile_rounded : Icons.desktop_windows_rounded),
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Install App for Fast & Offline Access',
                            style: GoogleFonts.oswald(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isIosSafari
                                ? "Tap Share → 'Add to Home Screen'"
                                : "1-Click install for desktop and mobile offline POS",
                            style: TextStyle(
                              color: isIosSafari ? Colors.amberAccent : Colors.white70,
                              fontSize: 11,
                              fontWeight: isIosSafari ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _dismissed = true),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                if (canInstall && !isIosSafari) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_provider.dart';

class CloudSyncIndicator extends ConsumerStatefulWidget {
  final double size;

  const CloudSyncIndicator({
    super.key,
    this.size = 18.0,
  });

  @override
  ConsumerState<CloudSyncIndicator> createState() => _CloudSyncIndicatorState();
}

class _CloudSyncIndicatorState extends ConsumerState<CloudSyncIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _manualSyncing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(bool isSyncing, bool isOffline) async {
    if (isSyncing || _manualSyncing) return;

    HapticFeedback.lightImpact();
    setState(() => _manualSyncing = true);
    _animationController.repeat();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Syncing with cloud...'),
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await ref.read(syncProvider.notifier).syncAll();
    } finally {
      // Keep animation running for at least 1.2s for pleasant visual feedback
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() => _manualSyncing = false);
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isProviderSyncing = ref.watch(isSyncingProvider);
    final connectivity = ref.watch(connectivityStatusProvider);
    final isOffline = connectivity.when(
      data: (results) => results.every((r) => r == ConnectivityResult.none),
      loading: () => false,
      error: (_, _) => false,
    );

    final bool isSyncing = isProviderSyncing || _manualSyncing;

    if (isSyncing && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!isSyncing && _animationController.isAnimating && !_manualSyncing) {
      _animationController.stop();
      _animationController.reset();
    }

    String tooltip;
    Color iconColor;
    Color borderColor;
    Color bgColor;

    if (isOffline) {
      tooltip = 'Offline (Local changes saved)';
      iconColor = Colors.amberAccent;
      borderColor = Colors.amberAccent.withValues(alpha: 0.4);
      bgColor = Colors.amber.withValues(alpha: 0.15);
    } else if (isSyncing) {
      tooltip = 'Syncing data with cloud...';
      iconColor = Colors.cyanAccent;
      borderColor = Colors.cyanAccent.withValues(alpha: 0.5);
      bgColor = Colors.cyanAccent.withValues(alpha: 0.15);
    } else {
      tooltip = 'Cloud Synced • Tap to refresh';
      iconColor = Colors.white.withValues(alpha: 0.9);
      borderColor = Colors.white.withValues(alpha: 0.2);
      bgColor = Colors.white.withValues(alpha: 0.1);
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(isSyncing, isOffline),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOffline) ...[
                  Icon(
                    Icons.cloud_off_rounded,
                    size: widget.size,
                    color: iconColor,
                  ),
                ] else if (isSyncing) ...[
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          size: widget.size,
                          color: iconColor.withValues(alpha: 0.5),
                        ),
                        RotationTransition(
                          turns: _animationController,
                          child: Icon(
                            Icons.sync_rounded,
                            size: widget.size * 0.72,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.cloud_done_rounded,
                    size: widget.size,
                    color: iconColor,
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

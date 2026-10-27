import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_provider.dart';

class CloudSyncIndicator extends ConsumerStatefulWidget {
  final double size;
  final bool compact;

  const CloudSyncIndicator({
    super.key,
    this.size = 18.0,
    this.compact = false,
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
      iconColor = const Color(0xFFFF5252); // Bright Red when offline
      borderColor = Colors.redAccent.withValues(alpha: 0.5);
      bgColor = Colors.red.withValues(alpha: 0.2);
    } else if (isSyncing) {
      tooltip = 'Syncing data with cloud...';
      iconColor = const Color(0xFFFF9100); // Bright Orange when syncing
      borderColor = Colors.orangeAccent.withValues(alpha: 0.5);
      bgColor = Colors.orange.withValues(alpha: 0.2);
    } else {
      tooltip = 'Cloud Synced • Tap to refresh';
      iconColor = const Color(0xFF00E676); // Bright Green when online & synced
      borderColor = Colors.greenAccent.withValues(alpha: 0.5);
      bgColor = Colors.green.withValues(alpha: 0.2);
    }

    if (widget.compact) {
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
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 0.9),
              ),
              child: isOffline
                  ? Icon(Icons.cloud_off_rounded, size: widget.size * 0.85, color: iconColor)
                  : isSyncing
                      ? SizedBox(
                          width: widget.size * 0.85,
                          height: widget.size * 0.85,
                          child: RotationTransition(
                            turns: _animationController,
                            child: Icon(Icons.sync_rounded, size: widget.size * 0.85, color: iconColor),
                          ),
                        )
                      : Icon(Icons.cloud_done_rounded, size: widget.size * 0.85, color: iconColor),
            ),
          ),
        ),
      );
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
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.9),
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
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
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
                  const SizedBox(width: 4),
                  Text(
                    'Syncing',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.cloud_done_rounded,
                    size: widget.size,
                    color: iconColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Synced',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
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

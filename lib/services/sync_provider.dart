import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'customer_provider.dart';
import 'expense_provider.dart';
import 'user_provider.dart';
import 'product_service.dart';
import 'sale_provider.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';

class SyncNotifier extends StateNotifier<DateTime> with WidgetsBindingObserver {
  final Ref ref;
  Timer? _timer;
  bool _isSyncing = false;

  SyncNotifier(this.ref) : super(DateTime.now()) {
    WidgetsBinding.instance.addObserver(this);
    _startSyncTimer();
    // Initial sync on startup
    _syncAll();
  }

  Future<void> syncAll() => _syncAll();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('Sync Monitor: App Resumed. Forcing immediate cloud sync...');
      _syncAll();
    }
  }

  void _startSyncTimer() {
    _timer?.cancel();
    // Process pending offline sync queue every 3 minutes (Realtime streams handle live data pushes)
    _timer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _processOfflineQueueOnly();
    });
  }

  Future<void> _processOfflineQueueOnly() async {
    if (!mounted || _isSyncing) return;
    try {
      await OfflineSyncService.processQueue();
    } catch (e) {
      debugPrint('Queue Process Error: $e');
    }
  }

  Future<void> _syncAll() async {
    if (!mounted || _isSyncing) return;

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      _isSyncing = true;
      ref.read(isSyncingProvider.notifier).state = true;
      
      // 1. Process offline queue first
      await OfflineSyncService.processQueue();
      
      // 2. Refresh key data sets on explicit user pull-to-refresh or app resume
      await Future.wait([
        _safeRefresh(productsFutureProvider.notifier, (n) => n.loadProducts()),
        _safeRefresh(customerProvider.notifier, (n) => n.loadCustomers()),
        _safeRefresh(saleHistoryProvider.notifier, (n) => n.loadSales()),
        _safeRefresh(expenseProvider.notifier, (n) => n.loadExpenses()),
        _safeRefresh(notificationProvider.notifier, (n) => n.loadNotifications()),
      ]);

      if (mounted) {
        state = DateTime.now(); 
      }
    } catch (e) {
      debugPrint('Sync Heartbeat Warning: $e');
    } finally {
      _isSyncing = false;
      ref.read(isSyncingProvider.notifier).state = false;
    }
  }

  Future<void> _safeRefresh<T>(ProviderListenable<T> provider, Future<void> Function(T) action) async {
    try {
      final notifier = ref.read(provider);
      await action(notifier);
    } catch (e) {
      // Silently ignore if provider is disposed or not found
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, DateTime>((ref) {
  return SyncNotifier(ref);
});

final isSyncingProvider = StateProvider<bool>((ref) => false);

final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  // Yield initial state
  yield await Connectivity().checkConnectivity();
  // Then yield subsequent changes
  yield* Connectivity().onConnectivityChanged;
});

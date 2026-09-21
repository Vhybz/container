import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/services/offline_sync_service.dart';

void main() {
  group('SyncStatus & Offline Sync Data Structure Tests', () {
    test('SyncStatus initial state values', () {
      final status = SyncStatus(
        pendingCount: 5,
        isSyncing: true,
        lastError: null,
      );

      expect(status.pendingCount, equals(5));
      expect(status.isSyncing, isTrue);
      expect(status.lastError, isNull);
    });

    test('SyncStatus with error message', () {
      final statusWithError = SyncStatus(
        pendingCount: 2,
        isSyncing: false,
        lastError: 'Network unreachable',
      );

      expect(statusWithError.pendingCount, equals(2));
      expect(statusWithError.isSyncing, isFalse);
      expect(statusWithError.lastError, equals('Network unreachable'));
    });
  });
}

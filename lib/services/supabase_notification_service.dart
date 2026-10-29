import 'package:flutter/foundation.dart';
import '../models/system_models.dart';
import 'supabase_base_service.dart';

class SupabaseNotificationService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => ['branch_code', 'user_id', 'is_read'];

  Stream<List<SystemNotification>> watchNotifications(String? branchCode, String? userId, {bool isSuperAdmin = false}) {
    if (!isSuperAdmin && branchCode == null && userId == null) return Stream.value([]);

    final String? cleanBranch = branchCode?.trim();

    return watchTable('notifications', order: 'created_at', limit: 30)
        .map((data) => data
            .map((json) => SystemNotification.fromJson(json))
            .where((n) {
              if (isSuperAdmin) return true;
              if (n.branchCode == null && n.userId == null) return true;
              if (cleanBranch != null && n.branchCode?.trim() == cleanBranch) return true;
              if (userId != null && n.userId == userId) return true;
              return false;
            })
            .toList()
            .reversed
            .toList());
  }

  Future<void> addNotification(SystemNotification notification) async {
    await robustOperation('notifications', notification.toJson());
  }

  Future<void> markAsRead(String id) async {
    await client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllAsRead(String userId, String? branchCode, {bool isSuperAdmin = false}) async {
    try {
      final String cleanBranch = (branchCode ?? '').trim();
      
      if (isSuperAdmin) {
        await client.from('notifications').update({'is_read': true}).eq('is_read', false);
      } else {
        await client.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
        if (cleanBranch.isNotEmpty) {
          await client.from('notifications').update({'is_read': true}).eq('branch_code', cleanBranch).eq('is_read', false);
        }
        await client.from('notifications').update({'is_read': true}).filter('user_id', 'is', null).filter('branch_code', 'is', null).eq('is_read', false);
      }
    } catch (e) {
      debugPrint('Mark All Read Error: $e');
    }
  }
}

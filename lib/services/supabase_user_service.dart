import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_base_service.dart';
import '../core/supabase_config.dart';

class SupabaseUserService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => [
        'temporary_role',
        'temp_role_start',
        'temp_role_end',
        'salary_amount',
        'salary_day',
        'last_salary_date',
        'total_salary_paid',
        'total_advances_taken',
        'theme_mode',
        'theme_primary_color'
      ];

  Future<List<UserAccount>> getUsers() async {
    final response = await selectSorted('users', filters: {'is_deleted': false});
    return response.map((json) => UserAccount.fromJson(json)).toList();
  }

  Future<void> addUser(UserAccount account) async {
    final data = account.toJson();
    data['is_deleted'] = false;
    await robustOperation('users', data);
  }

  Future<void> updateUser(UserAccount account) async {
    await robustOperation('users', account.toJson(), isUpdate: true, updateId: account.id);
  }

  Future<void> updateUserFields(String userId, Map<String, dynamic> fields) async {
    await client.from('users').update(fields).eq('id', userId);
  }

  Future<void> deleteUser(String id) async {
    await client.from('users').update({'is_deleted': true}).eq('id', id);
  }

  Future<void> hardDeleteUser(String id) async {
    await client.from('users').delete().eq('id', id);
    try {
      await SupabaseConfig.adminClient.auth.admin.deleteUser(id);
    } catch (e) {
      debugPrint('SupabaseUserService: Auth cleanup failed: $e');
    }
  }

  Future<UserAccount?> getUserById(String id) async {
    try {
      final response = await client.from('users').select().eq('id', id).single();
      return UserAccount.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<UserAccount?> getCurrentUser() async {
    try {
      final user = client.auth.currentUser;
      if (user == null) return null;
      return await getUserById(user.id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> checkPhoneExists(String phone) async {
    try {
      final response = await client.from('users').select('phone').eq('phone', phone).limit(1).maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<String?> uploadProfilePicture(String userId, Uint8List bytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_$timestamp.jpg';
      final path = 'profiles/$fileName';

      try {
        final List<FileObject> existingFiles = await client.storage.from('user-profiles').list(path: 'profiles');
        final List<String> userFiles = existingFiles.where((f) => f.name.startsWith(userId)).map((f) => 'profiles/${f.name}').toList();

        if (userFiles.isNotEmpty) {
          await client.storage.from('user-profiles').remove(userFiles);
        }
      } catch (_) {}

      await client.storage.from('user-profiles').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return client.storage.from('user-profiles').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  Stream<UserAccount?> streamUser(String id) {
    return client.from('users').stream(primaryKey: ['id']).eq('id', id).map((data) => data.isEmpty ? null : UserAccount.fromJson(data.first));
  }

  Stream<List<UserAccount>> watchUsers() {
    return watchTable('users').map((data) => data.map((json) => UserAccount.fromJson(json)).where((u) => !u.isDeleted).toList());
  }
}

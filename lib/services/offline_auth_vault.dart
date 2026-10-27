import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';

class OfflineAuthVault {
  static const String _vaultBoxName = 'offline_auth_vault';
  static const String _salt = 'CONTAINER_STORES_SECURE_SALT_2026';

  /// Hashes email and password with salted SHA-256
  static String hashCredentials(String email, String password) {
    final bytes = utf8.encode('$email:$_salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Securely stores encrypted credential hash and user account JSON in Hive
  static Future<void> storeCredentials(String email, String password, UserAccount user) async {
    try {
      final box = await Hive.openBox<String>(_vaultBoxName);
      final hash = hashCredentials(email.trim().toLowerCase(), password);

      final vaultEntry = {
        'hash': hash,
        'email': email.trim().toLowerCase(),
        'user': user.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await box.put(email.trim().toLowerCase(), jsonEncode(vaultEntry));
      debugPrint('OfflineAuthVault: Credentials and user profile securely cached for ${user.email}');
    } catch (e) {
      debugPrint('OfflineAuthVault Store Error: $e');
    }
  }

  /// Verifies credentials offline against the local vault
  static Future<UserAccount?> verifyOffline(String email, String password) async {
    try {
      final box = await Hive.openBox<String>(_vaultBoxName);
      final rawEntry = box.get(email.trim().toLowerCase());

      if (rawEntry == null) return null;

      final Map<String, dynamic> entry = jsonDecode(rawEntry);
      final storedHash = entry['hash'] as String?;
      final inputHash = hashCredentials(email.trim().toLowerCase(), password);

      if (storedHash == inputHash) {
        final userData = entry['user'] as Map<String, dynamic>;
        debugPrint('OfflineAuthVault: Offline authentication successful for $email');
        return UserAccount.fromJson(userData);
      } else {
        debugPrint('OfflineAuthVault: Invalid password attempt offline for $email');
        return null;
      }
    } catch (e) {
      debugPrint('OfflineAuthVault Verify Error: $e');
      return null;
    }
  }
}

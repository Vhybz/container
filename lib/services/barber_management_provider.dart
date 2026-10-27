import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/barbershop_models.dart';
import 'user_provider.dart';
import 'barber_queue_provider.dart';

class CustomBarber {
  final String id;
  final String name;
  final String phone;
  final bool isCustom;
  final String? userId;

  CustomBarber({
    required this.id,
    required this.name,
    this.phone = '',
    this.isCustom = true,
    this.userId,
  });

  factory CustomBarber.fromJson(Map<String, dynamic> json) {
    return CustomBarber(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Barber',
      phone: json['phone'] as String? ?? '',
      isCustom: json['is_custom'] as bool? ?? true,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'is_custom': isCustom,
    if (userId != null) 'user_id': userId,
  };

  CustomBarber copyWith({
    String? id,
    String? name,
    String? phone,
    bool? isCustom,
    String? userId,
  }) {
    return CustomBarber(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isCustom: isCustom ?? this.isCustom,
      userId: userId ?? this.userId,
    );
  }
}

class BarberManagementState {
  final List<CustomBarber> customBarbers;
  final Set<String> clearedUnknownBarbers;

  BarberManagementState({
    required this.customBarbers,
    required this.clearedUnknownBarbers,
  });

  BarberManagementState copyWith({
    List<CustomBarber>? customBarbers,
    Set<String>? clearedUnknownBarbers,
  }) {
    return BarberManagementState(
      customBarbers: customBarbers ?? this.customBarbers,
      clearedUnknownBarbers: clearedUnknownBarbers ?? this.clearedUnknownBarbers,
    );
  }
}

class BarberManagementNotifier extends StateNotifier<BarberManagementState> {
  static const String _customBoxName = 'custom_barbers_box';
  static const String _clearedBoxName = 'cleared_barbers_box';
  final Ref ref;

  BarberManagementNotifier(this.ref)
      : super(BarberManagementState(customBarbers: [], clearedUnknownBarbers: {})) {
    _init();
  }

  Future<void> _init() async {
    try {
      final customBox = await Hive.openBox<String>(_customBoxName);
      final clearedBox = await Hive.openBox<String>(_clearedBoxName);

      // Load custom barbers
      final rawCustom = customBox.get('custom_barbers_list');
      List<CustomBarber> loadedCustom = [];
      if (rawCustom != null) {
        final List decoded = jsonDecode(rawCustom);
        loadedCustom = decoded.map((e) => CustomBarber.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      // Load cleared unknown barbers
      final rawCleared = clearedBox.get('cleared_barbers_set');
      Set<String> loadedCleared = {};
      if (rawCleared != null) {
        final List decoded = jsonDecode(rawCleared);
        loadedCleared = decoded.map((e) => e.toString().trim().toLowerCase()).toSet();
      }

      state = BarberManagementState(
        customBarbers: loadedCustom,
        clearedUnknownBarbers: loadedCleared,
      );
    } catch (e) {
      debugPrint('BarberManagementNotifier init error: $e');
    }
  }

  Future<void> _saveCustomToCache(List<CustomBarber> list) async {
    try {
      final box = await Hive.openBox<String>(_customBoxName);
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await box.put('custom_barbers_list', jsonStr);
    } catch (e) {
      debugPrint('Error saving custom barbers: $e');
    }
  }

  Future<void> _saveClearedToCache(Set<String> set) async {
    try {
      final box = await Hive.openBox<String>(_clearedBoxName);
      final jsonStr = jsonEncode(set.toList());
      await box.put('cleared_barbers_set', jsonStr);
    } catch (e) {
      debugPrint('Error saving cleared barbers: $e');
    }
  }

  /// Adds a new custom barber
  Future<void> addCustomBarber(String name, {String phone = '', String? userId}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final newBarber = CustomBarber(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
      phone: phone.trim(),
      userId: userId,
    );

    // Remove from cleared set if it was previously cleared
    final updatedCleared = Set<String>.from(state.clearedUnknownBarbers)
      ..remove(cleanName.toLowerCase());

    final updatedCustom = [...state.customBarbers.where((b) => b.name.toLowerCase() != cleanName.toLowerCase()), newBarber];

    state = state.copyWith(customBarbers: updatedCustom, clearedUnknownBarbers: updatedCleared);
    await _saveCustomToCache(updatedCustom);
    await _saveClearedToCache(updatedCleared);
  }

  /// Edits an existing barber (custom or user account)
  Future<void> editBarber(String oldName, String newName, {String? newPhone, String? userId}) async {
    final cleanOld = oldName.trim();
    final cleanNew = newName.trim();
    if (cleanNew.isEmpty) return;

    // 1. If linked to user account, update user account as well
    if (userId != null && userId.isNotEmpty) {
      final parts = cleanNew.split(' ');
      final firstName = parts.first;
      final surname = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      await ref.read(userProvider.notifier).updateProfile(userId, firstName: firstName, surname: surname, phone: newPhone);
    }

    // 2. Update in custom barbers list if present
    bool foundInCustom = false;
    final updatedCustom = state.customBarbers.map((b) {
      if (b.name.toLowerCase() == cleanOld.toLowerCase() || (userId != null && b.userId == userId)) {
        foundInCustom = true;
        return b.copyWith(name: cleanNew, phone: newPhone ?? b.phone, userId: userId ?? b.userId);
      }
      return b;
    }).toList();

    if (!foundInCustom) {
      updatedCustom.add(CustomBarber(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: cleanNew,
        phone: newPhone ?? '',
        userId: userId,
      ));
    }

    state = state.copyWith(customBarbers: updatedCustom);
    await _saveCustomToCache(updatedCustom);
  }

  /// Deletes a created/custom barber or user account barber
  Future<void> deleteBarber(String name, {String? userId}) async {
    final cleanName = name.trim();

    // 1. Delete user account if userId provided
    if (userId != null && userId.isNotEmpty) {
      try {
        await ref.read(userProvider.notifier).deleteUser(userId);
      } catch (e) {
        debugPrint('Delete user account error: $e');
      }
    }

    // 2. Delete from custom barbers
    final updatedCustom = state.customBarbers.where((b) => b.name.toLowerCase() != cleanName.toLowerCase() && b.userId != userId).toList();

    // 3. Mark name as cleared so legacy records don't bring it back as active
    final updatedCleared = Set<String>.from(state.clearedUnknownBarbers)..add(cleanName.toLowerCase());

    state = state.copyWith(customBarbers: updatedCustom, clearedUnknownBarbers: updatedCleared);
    await _saveCustomToCache(updatedCustom);
    await _saveClearedToCache(updatedCleared);
  }

  /// Clears an unknown/unrecognized barber name from active dropdown lists
  Future<void> clearUnknownBarber(String unknownName) async {
    final clean = unknownName.trim();
    if (clean.isEmpty) return;

    final updatedCleared = Set<String>.from(state.clearedUnknownBarbers)..add(clean.toLowerCase());
    
    // Also remove from custom barbers if it exists there
    final updatedCustom = state.customBarbers.where((b) => b.name.toLowerCase() != clean.toLowerCase()).toList();

    state = state.copyWith(customBarbers: updatedCustom, clearedUnknownBarbers: updatedCleared);
    await _saveClearedToCache(updatedCleared);
    await _saveCustomToCache(updatedCustom);
  }

  /// Clears multiple unknown barber names at once
  Future<void> clearAllUnknownBarbers(List<String> unknownNames) async {
    final updatedCleared = Set<String>.from(state.clearedUnknownBarbers);
    for (final name in unknownNames) {
      if (name.trim().isNotEmpty) {
        updatedCleared.add(name.trim().toLowerCase());
      }
    }

    state = state.copyWith(clearedUnknownBarbers: updatedCleared);
    await _saveClearedToCache(updatedCleared);
  }

  /// Restores a cleared unknown barber
  Future<void> restoreClearedBarber(String name) async {
    final clean = name.trim().toLowerCase();
    final updatedCleared = Set<String>.from(state.clearedUnknownBarbers)..remove(clean);

    state = state.copyWith(clearedUnknownBarbers: updatedCleared);
    await _saveClearedToCache(updatedCleared);
  }

  /// Returns clean compiled list of active barbers (Staff + Custom Barbers - Cleared Barbers)
  List<String> getCompiledBarbers({
    required List<UserAccount> staff,
    List<BarberRecord>? records,
    List<BarberQueueItem>? queue,
  }) {
    final Set<String> activeNames = {};

    // 1. Registered staff members with Barber, Secretary, or Admin role
    for (final u in staff) {
      if (u.isDeleted || u.status != AccountStatus.approved) continue;
      final isBarberStaff = u.role == UserRole.barber ||
          u.secondaryRoles.contains(UserRole.barber) ||
          u.role == UserRole.admin ||
          u.role == UserRole.superAdmin ||
          u.role == UserRole.secretary;

      if (isBarberStaff) {
        activeNames.add(u.name.trim());
      }
    }

    // 2. Custom created barbers
    for (final cb in state.customBarbers) {
      if (cb.name.trim().isNotEmpty) {
        activeNames.add(cb.name.trim());
      }
    }

    // Filter out any names that have been marked as cleared/deleted
    final filtered = activeNames.where((name) {
      final lower = name.trim().toLowerCase();
      return !state.clearedUnknownBarbers.contains(lower);
    }).toList();

    filtered.sort();

    // Fallback if list is completely empty
    if (filtered.isEmpty) {
      return ['Default Stylist'];
    }

    return filtered;
  }

  /// Identifies "Unknown/Legacy" barber names currently in system records that are not in active staff/custom list
  List<String> getUnknownBarbers({
    required List<UserAccount> staff,
    required List<BarberRecord> records,
    List<BarberQueueItem>? queue,
  }) {
    final activeNames = getCompiledBarbers(staff: staff).map((n) => n.trim().toLowerCase()).toSet();
    final Set<String> unknownFound = {};

    // Check service records
    for (final r in records) {
      final bName = r.barber.trim();
      if (bName.isNotEmpty) {
        final lower = bName.toLowerCase();
        if (!activeNames.contains(lower) && !state.clearedUnknownBarbers.contains(lower)) {
          unknownFound.add(bName);
        }
      }
    }

    // Check queue
    if (queue != null) {
      for (final q in queue) {
        final bName = q.barber.trim();
        if (bName.isNotEmpty) {
          final lower = bName.toLowerCase();
          if (!activeNames.contains(lower) && !state.clearedUnknownBarbers.contains(lower)) {
            unknownFound.add(bName);
          }
        }
      }
    }

    // Check default hardcoded names if present
    const hardcodedDefaults = ['King Mojo', 'Stylist Sarah', 'Barber Frank'];
    for (final h in hardcodedDefaults) {
      final lower = h.toLowerCase();
      if (!activeNames.contains(lower) && !state.clearedUnknownBarbers.contains(lower)) {
        unknownFound.add(h);
      }
    }

    return unknownFound.toList()..sort();
  }
}

final barberManagementProvider = StateNotifierProvider<BarberManagementNotifier, BarberManagementState>((ref) {
  return BarberManagementNotifier(ref);
});

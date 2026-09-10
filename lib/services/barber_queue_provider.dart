import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'sms_service.dart';

class BarberQueueItem {
  final String id;
  final String branchCode;
  final String customer;
  final String phone;
  final String service;
  final String barber;
  final String status; // 'Waiting', 'In Service', 'Completed', 'Cancelled'
  final DateTime timestamp;

  BarberQueueItem({
    required this.id,
    required this.branchCode,
    required this.customer,
    required this.phone,
    required this.service,
    required this.barber,
    required this.status,
    required this.timestamp,
  });

  factory BarberQueueItem.fromJson(Map<String, dynamic> json) {
    return BarberQueueItem(
      id: json['id'] as String,
      branchCode: json['branch_code'] as String? ?? 'MAIN',
      customer: json['customer'] as String? ?? 'Client',
      phone: json['phone'] as String? ?? '',
      service: json['service'] as String? ?? 'Haircut',
      barber: json['barber'] as String? ?? 'Stylist',
      status: json['status'] as String? ?? 'Waiting',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'branch_code': branchCode,
    'customer': customer,
    'phone': phone,
    'service': service,
    'barber': barber,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
  };

  BarberQueueItem copyWith({
    String? id,
    String? branchCode,
    String? customer,
    String? phone,
    String? service,
    String? barber,
    String? status,
    DateTime? timestamp,
  }) {
    return BarberQueueItem(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      customer: customer ?? this.customer,
      phone: phone ?? this.phone,
      service: service ?? this.service,
      barber: barber ?? this.barber,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class BarberQueueNotifier extends StateNotifier<List<BarberQueueItem>> {
  final Ref ref;
  static const String _boxName = 'barber_queue_box';

  BarberQueueNotifier(this.ref) : super([]) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawList = box.get('queue_list');
      if (rawList != null) {
        final List decoded = jsonDecode(rawList);
        state = decoded.map((e) => BarberQueueItem.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        // Seed default initial queue item
        state = [
          BarberQueueItem(
            id: 'Q-101',
            branchCode: 'MAIN',
            customer: 'Kofi Badu',
            phone: '0241234567',
            service: 'Executive Haircut',
            barber: 'Master Barber Frank',
            status: 'In Service',
            timestamp: DateTime.now(),
          ),
        ];
        _saveToCache(state);
      }
    } catch (e) {
      debugPrint('Error loading barber queue: $e');
    }
  }

  Future<void> _saveToCache(List<BarberQueueItem> list) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await box.put('queue_list', jsonStr);
    } catch (e) {
      debugPrint('Error saving barber queue: $e');
    }
  }

  Future<void> addToQueue({
    required String customer,
    required String phone,
    required String service,
    required String barber,
  }) async {
    final user = ref.read(currentUserProvider);
    final String queueId = 'Q-${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(3, '0')}';
    
    final newItem = BarberQueueItem(
      id: queueId,
      branchCode: user?.branchCode ?? 'MAIN',
      customer: customer.trim(),
      phone: phone.trim(),
      service: service,
      barber: barber,
      status: 'Waiting',
      timestamp: DateTime.now(),
    );

    state = [newItem, ...state];
    await _saveToCache(state);

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('barber_queue').upsert(newItem.toJson());
      }
    } catch (e) {
      debugPrint('Supabase queue sync notice: $e');
    }
  }

  Future<void> updateStatus(String queueId, String newStatus) async {
    state = state.map((item) {
      if (item.id == queueId) {
        final updated = item.copyWith(status: newStatus);

        // Send instant post-haircut SMS if completed
        if (newStatus == 'Completed' && updated.phone.isNotEmpty) {
          SmsService.sendPostHaircutSms(
            name: updated.customer,
            phone: updated.phone,
            serviceName: updated.service,
            barberName: updated.barber,
          );
        }
        return updated;
      }
      return item;
    }).toList();

    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('barber_queue').update({'status': newStatus}).eq('id', queueId);
      }
    } catch (e) {
      debugPrint('Supabase queue update notice: $e');
    }
  }

  Future<void> removeFromQueue(String queueId) async {
    state = state.where((item) => item.id != queueId).toList();
    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('barber_queue').delete().eq('id', queueId);
      }
    } catch (e) {
      debugPrint('Supabase queue delete notice: $e');
    }
  }
}

final barberQueueProvider = StateNotifierProvider<BarberQueueNotifier, List<BarberQueueItem>>((ref) {
  return BarberQueueNotifier(ref);
});

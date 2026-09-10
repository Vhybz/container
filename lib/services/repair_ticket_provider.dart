import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'sms_service.dart';

class RepairTicket {
  final String id;
  final String branchCode;
  final String customer;
  final String phone;
  final String device;
  final String issue;
  final String status; // 'Received', 'In Progress', 'Ready for Pickup', 'Delivered'
  final double cost;
  final double deposit;
  final String technician;
  final DateTime timestamp;

  RepairTicket({
    required this.id,
    required this.branchCode,
    required this.customer,
    required this.phone,
    required this.device,
    required this.issue,
    required this.status,
    required this.cost,
    this.deposit = 0.0,
    required this.technician,
    required this.timestamp,
  });

  factory RepairTicket.fromJson(Map<String, dynamic> json) {
    return RepairTicket(
      id: json['id'] as String,
      branchCode: json['branch_code'] as String? ?? 'MAIN',
      customer: json['customer'] as String? ?? 'Customer',
      phone: json['phone'] as String? ?? '',
      device: json['device'] as String? ?? 'Phone',
      issue: json['issue'] as String? ?? 'Repair',
      status: json['status'] as String? ?? 'Received',
      cost: (json['cost'] as num? ?? 0.0).toDouble(),
      deposit: (json['deposit'] as num? ?? 0.0).toDouble(),
      technician: json['technician'] as String? ?? 'Tech Rep',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'branch_code': branchCode,
    'customer': customer,
    'phone': phone,
    'device': device,
    'issue': issue,
    'status': status,
    'cost': cost,
    'deposit': deposit,
    'technician': technician,
    'timestamp': timestamp.toIso8601String(),
  };

  RepairTicket copyWith({
    String? id,
    String? branchCode,
    String? customer,
    String? phone,
    String? device,
    String? issue,
    String? status,
    double? cost,
    double? deposit,
    String? technician,
    DateTime? timestamp,
  }) {
    return RepairTicket(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      customer: customer ?? this.customer,
      phone: phone ?? this.phone,
      device: device ?? this.device,
      issue: issue ?? this.issue,
      status: status ?? this.status,
      cost: cost ?? this.cost,
      deposit: deposit ?? this.deposit,
      technician: technician ?? this.technician,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class RepairTicketNotifier extends StateNotifier<List<RepairTicket>> {
  final Ref ref;
  static const String _boxName = 'repair_tickets_box';

  RepairTicketNotifier(this.ref) : super([]) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawList = box.get('tickets_list');
      if (rawList != null) {
        final List decoded = jsonDecode(rawList);
        state = decoded.map((e) => RepairTicket.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        // Seed default initial repair ticket
        state = [
          RepairTicket(
            id: 'REP-1021',
            branchCode: 'MAIN',
            customer: 'Emmanuel Ofori',
            phone: '0249876543',
            device: 'iPhone 13',
            issue: 'Screen & Battery Replacement',
            status: 'In Progress',
            cost: 1200.0,
            deposit: 500.0,
            technician: 'Tech Specialist',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
        _saveToCache(state);
      }
    } catch (e) {
      debugPrint('Error loading repair tickets: $e');
    }
  }

  Future<void> _saveToCache(List<RepairTicket> list) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await box.put('tickets_list', jsonStr);
    } catch (e) {
      debugPrint('Error saving repair tickets: $e');
    }
  }

  Future<void> addWorkOrder({
    required String customer,
    required String phone,
    required String device,
    required String issue,
    required double cost,
    required double deposit,
    required String technician,
  }) async {
    final user = ref.read(currentUserProvider);
    final String ticketId = 'REP-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(4, '0')}';

    final newTicket = RepairTicket(
      id: ticketId,
      branchCode: user?.branchCode ?? 'MAIN',
      customer: customer.trim(),
      phone: phone.trim(),
      device: device.trim(),
      issue: issue.trim(),
      status: 'Received',
      cost: cost,
      deposit: deposit,
      technician: technician,
      timestamp: DateTime.now(),
    );

    state = [newTicket, ...state];
    await _saveToCache(state);

    // Notify customer via SMS
    if (phone.trim().isNotEmpty) {
      SmsService.sendCustomSms(
        phone.trim(),
        'Hello $customer, your repair work order #$ticketId for $device has been registered at Container Tech Shop. Cost: GHS ${cost.toStringAsFixed(2)}. Thank you!',
      );
    }

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('repair_tickets').upsert(newTicket.toJson());
      }
    } catch (e) {
      debugPrint('Supabase repair ticket sync notice: $e');
    }
  }

  Future<void> updateStatus(String ticketId, String newStatus) async {
    state = state.map((ticket) {
      if (ticket.id == ticketId) {
        final updated = ticket.copyWith(status: newStatus);

        // Send SMS update to customer if ready for pickup
        if (newStatus == 'Ready for Pickup' && updated.phone.isNotEmpty) {
          final balance = updated.cost - updated.deposit;
          String msg = 'Hello ${updated.customer}, your ${updated.device} repair (#${updated.id}) is READY FOR PICKUP at Container Tech Shop!';
          if (balance > 0.01) {
            msg += ' Remaining Balance: GHS ${balance.toStringAsFixed(2)}.';
          }
          SmsService.sendCustomSms(updated.phone, msg);
        }
        return updated;
      }
      return ticket;
    }).toList();

    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('repair_tickets').update({'status': newStatus}).eq('id', ticketId);
      }
    } catch (e) {
      debugPrint('Supabase repair ticket status update notice: $e');
    }
  }

  Future<void> deleteTicket(String ticketId) async {
    state = state.where((t) => t.id != ticketId).toList();
    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('repair_tickets').delete().eq('id', ticketId);
      }
    } catch (e) {
      debugPrint('Supabase repair ticket delete notice: $e');
    }
  }
}

final repairTicketProvider = StateNotifierProvider<RepairTicketNotifier, List<RepairTicket>>((ref) {
  return RepairTicketNotifier(ref);
});

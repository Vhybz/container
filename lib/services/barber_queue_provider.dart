import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/supabase_config.dart';
import '../models/sale_model.dart';
import '../models/product.dart';
import 'user_provider.dart';
import 'product_service.dart';
import 'sale_provider.dart';
import 'receipt_service.dart';
import 'sms_service.dart';
import 'barber_records_provider.dart';

class BarberQueueItem {
  final String id;
  final String branchCode;
  final String customer;
  final String phone;
  final String service;
  final String barber;
  final String status; // 'Waiting', 'In Service', 'Completed', 'Cancelled'
  final DateTime timestamp;
  final double? price;
  final String? saleId;
  final bool isAppointment;
  final String? appointmentId;
  final DateTime? appointmentTime;

  BarberQueueItem({
    required this.id,
    required this.branchCode,
    required this.customer,
    required this.phone,
    required this.service,
    required this.barber,
    required this.status,
    required this.timestamp,
    this.price,
    this.saleId,
    this.isAppointment = false,
    this.appointmentId,
    this.appointmentTime,
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
      price: (json['price'] as num?)?.toDouble(),
      saleId: json['sale_id'] as String?,
      isAppointment: json['is_appointment'] == true,
      appointmentId: json['appointment_id'] as String?,
      appointmentTime: json['appointment_time'] != null ? DateTime.tryParse(json['appointment_time']) : null,
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
    if (price != null) 'price': price,
    if (saleId != null) 'sale_id': saleId,
    if (isAppointment) 'is_appointment': isAppointment,
    if (appointmentId != null) 'appointment_id': appointmentId,
    if (appointmentTime != null) 'appointment_time': appointmentTime!.toIso8601String(),
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
    double? price,
    String? saleId,
    bool? isAppointment,
    String? appointmentId,
    DateTime? appointmentTime,
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
      price: price ?? this.price,
      saleId: saleId ?? this.saleId,
      isAppointment: isAppointment ?? this.isAppointment,
      appointmentId: appointmentId ?? this.appointmentId,
      appointmentTime: appointmentTime ?? this.appointmentTime,
    );
  }
}

class BarberQueueNotifier extends StateNotifier<List<BarberQueueItem>> {
  final Ref ref;
  static const String _boxName = 'barber_queue_box';

  BarberQueueNotifier(this.ref) : super([]) {
    _loadFromCache();
  }

  static double getDefaultPrice(String service) {
    final s = service.toLowerCase();
    if (s.contains('kid')) return 30.0;
    if (s.contains('beard')) return 30.0;
    if (s.contains('dye') || s.contains('black')) return 45.0;
    if (s.contains('facial') || s.contains('scrub') || s.contains('steam')) return 60.0;
    return 50.0; // Standard Executive Haircut
  }

  Future<void> _loadFromCache() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawList = box.get('queue_list');
      if (rawList != null) {
        final List decoded = jsonDecode(rawList);
        final loaded = decoded
            .map((e) => BarberQueueItem.fromJson(Map<String, dynamic>.from(e)))
            .where((q) => q.id != 'Q-101' && q.id != 'Q-102' && q.customer != 'Kofi Badu' && q.customer != 'Yaw Boateng')
            .toList();
        state = loaded;
        _saveToCache(loaded);
      } else {
        state = [];
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
    double? price,
    bool isAppointment = false,
    String? appointmentId,
    DateTime? appointmentTime,
    bool sendSms = true,
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
      price: price ?? getDefaultPrice(service),
      isAppointment: isAppointment,
      appointmentId: appointmentId,
      appointmentTime: appointmentTime,
    );

    state = [newItem, ...state];
    await _saveToCache(state);

    // Send SMS confirmation to customer with queue position if requested
    if (sendSms && phone.trim().isNotEmpty) {
      final waitingCount = state.where((q) => q.status == 'Waiting').length;
      SmsService.sendQueueConfirmationSms(
        name: customer.trim(),
        phone: phone.trim(),
        serviceName: service,
        barberName: barber,
        position: waitingCount,
        queueId: queueId,
      );
    }

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

  Future<SaleRecord?> completeAndAddToSales(
    String queueId, {
    double? customPrice,
    String paymentMethod = 'Cash',
    double tip = 0.0,
    bool printReceipt = false,
  }) async {
    final itemIndex = state.indexWhere((i) => i.id == queueId);
    if (itemIndex == -1) return null;

    final item = state[itemIndex];
    if (item.status == 'Completed' && item.saleId != null) {
      debugPrint('Queue item $queueId is already completed and recorded to sales (${item.saleId}).');
      return null;
    }

    final user = ref.read(currentUserProvider);
    final products = ref.read(productsFutureProvider).value ?? [];

    final double finalPrice = customPrice ?? item.price ?? getDefaultPrice(item.service);
    final double grandTotal = finalPrice + tip;

    // Look for matching product in active catalog
    Product? matchedProduct;
    for (final p in products) {
      if (p.name.toLowerCase() == item.service.toLowerCase()) {
        matchedProduct = p;
        break;
      }
    }

    final productToUse = matchedProduct ?? Product(
      id: 'srv-${item.service.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
      name: item.service,
      imageUrl: '',
      category: 'Barbershop Services',
      retailPrice: finalPrice,
      costPrice: finalPrice * 0.7,
      wholesalePrice: finalPrice,
      stockQuantity: 9999,
      unit: item.service.toLowerCase().contains('shave') ? 'shave' : 'cut',
      isService: true,
      isUnlimited: true,
      branchCode: item.branchCode,
    );

    final saleItems = [
      SaleItem(
        product: productToUse,
        quantity: 1,
        priceAtSale: finalPrice,
        originalPrice: finalPrice,
      ),
    ];

    final PaymentMethod mode = paymentMethod == 'MoMo'
        ? PaymentMethod.mobileMoney
        : (paymentMethod == 'Card' ? PaymentMethod.bankDeposit : PaymentMethod.cash);

    final attendantName = user?.name ?? 'Staff';
    final cashierDisplay = item.barber.isNotEmpty
        ? '${item.barber} (Queue Attendant: $attendantName)'
        : attendantName;

    final saleId = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final sale = SaleRecord(
      id: saleId,
      branchCode: item.branchCode.isNotEmpty ? item.branchCode : (user?.branchCode ?? 'MAIN'),
      items: saleItems,
      totalAmount: grandTotal,
      totalDiscount: 0.0,
      totalCost: finalPrice * 0.7,
      payments: [PaymentDetail(method: mode, amount: grandTotal)],
      timestamp: DateTime.now(),
      cashierName: cashierDisplay,
      cashierId: user?.id ?? 'N/A',
      customerName: item.customer,
      customerPhone: item.phone.isNotEmpty ? item.phone : null,
      status: SaleStatus.completed,
      isVerified: true,
    );

    // 1. Record the cut directly into the POS Sales system
    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    // 1b. Permanently record into BarberRecords archive (retained even if queue cleared)
    final fixedComm = productToUse.serviceCommission > 0 ? productToUse.serviceCommission : null;
    await ref.read(barberRecordsProvider.notifier).recordService(
      customerName: item.customer,
      customerPhone: item.phone,
      service: item.service,
      barber: item.barber,
      price: finalPrice,
      tip: tip,
      paymentMethod: paymentMethod,
      attendant: attendantName,
      saleId: saleId,
      queueId: item.id,
      appointmentId: item.appointmentId,
      source: item.isAppointment ? 'Appointment' : 'Queue',
      commissionAmount: fixedComm,
      product: productToUse,
    );

    // 2. Print paper receipt if requested
    if (printReceipt) {
      ReceiptService.printReceipt(sale, context: null);
    }

    // 3. Send instant post-haircut SMS
    if (item.phone.trim().isNotEmpty) {
      if (item.service.toLowerCase().contains('kid')) {
        SmsService.sendKidHaircutSms(
          childName: item.customer,
          parentPhone: item.phone.trim(),
          serviceName: item.service,
          barberName: item.barber,
        );
      } else {
        SmsService.sendPostHaircutSms(
          name: item.customer,
          phone: item.phone.trim(),
          serviceName: item.service,
          barberName: item.barber,
        );
      }
    }

    // 4. Update queue state to Completed with sale ID and price
    final updatedItem = item.copyWith(
      status: 'Completed',
      price: finalPrice,
      saleId: saleId,
    );

    state = state.map((i) => i.id == queueId ? updatedItem : i).toList();
    await _saveToCache(state);

    // 5. Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('barber_queue').update({
          'status': 'Completed',
          'sale_id': saleId,
          'price': finalPrice,
        }).eq('id', queueId);
      }
    } catch (e) {
      debugPrint('Supabase queue complete notice: $e');
    }

    return sale;
  }

  Future<void> updateStatus(String queueId, String newStatus) async {
    if (newStatus == 'Completed') {
      await completeAndAddToSales(queueId);
      return;
    }

    state = state.map((item) {
      if (item.id == queueId) {
        return item.copyWith(status: newStatus);
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/supabase_config.dart';
import '../models/barbershop_models.dart';
import '../models/sale_model.dart';
import 'sale_provider.dart';
import 'barber_queue_provider.dart';
import 'barbershop_service.dart';
import 'product_service.dart';
import '../models/product.dart';

class BarberRecordsNotifier extends StateNotifier<List<BarberRecord>> {
  final Ref ref;
  static const String _boxName = 'barber_records_box';
  bool _isBackfilling = false;

  BarberRecordsNotifier(this.ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    await _fetchFromSupabase();
    // Run backfill after a short delay so other providers are loaded
    Future.delayed(const Duration(milliseconds: 600), () {
      _backfillFromExistingSalesAndQueue();
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawList = box.get('records_list');
      if (rawList != null) {
        final List decoded = jsonDecode(rawList);
        final loaded = decoded
            .map((e) => BarberRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading barber records from cache: $e');
    }
  }

  Future<void> _saveToCache(List<BarberRecord> list) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await box.put('records_list', jsonStr);
    } catch (e) {
      debugPrint('Error saving barber records to cache: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      final response = await SupabaseConfig.client
          .from('barber_records')
          .select()
          .order('timestamp', ascending: false);

      final List data = response as List? ?? [];
      if (data.isNotEmpty) {
        final remoteList = data
            .map((e) => BarberRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Merge remote with local to preserve newly created items
        final Map<String, BarberRecord> map = {
          for (var item in state) item.id: item,
        };
        for (var remote in remoteList) {
          map[remote.id] = remote;
        }
        final merged = map.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = merged;
        await _saveToCache(merged);
      }
    } catch (e) {
      debugPrint('Supabase barber records fetch notice: $e');
    }
  }

  /// Automatically backfills records from existing sales history and completed queue items
  Future<void> _backfillFromExistingSalesAndQueue() async {
    if (_isBackfilling || !mounted) return;
    _isBackfilling = true;

    try {
      final sales = ref.read(saleHistoryProvider);
      final queue = ref.read(barberQueueProvider);
      final existingSaleIds = state.map((r) => r.saleId).where((id) => id != null).toSet();
      final existingQueueIds = state.map((r) => r.queueId).where((id) => id != null).toSet();

      final List<BarberRecord> newRecords = [];

      // 1. Backfill from sales history
      for (final sale in sales) {
        if (existingSaleIds.contains(sale.id)) continue;

        // Check if this sale is for a barbershop service
        for (final item in sale.items) {
          final cat = item.product.category.toUpperCase();
          final name = item.product.name.toUpperCase();
          final isBarberItem = (cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || item.product.isService) &&
              !cat.contains('REPAIR') && !name.contains('IPHONE') && !name.contains('BATTERY');

          if (isBarberItem) {
            String barberName = 'King Mojo';
            final cashier = sale.cashierName;
            if (cashier.contains('(')) {
              barberName = cashier.split('(').first.trim();
            } else if (cashier.isNotEmpty) {
              barberName = cashier;
            }

            final paymentMethod = sale.payments.isNotEmpty
                ? (sale.payments.first.method == PaymentMethod.mobileMoney ? 'MoMo' : (sale.payments.first.method == PaymentMethod.bankDeposit ? 'Card' : 'Cash'))
                : 'Cash';

            final commAmount = item.product.serviceCommission > 0
                ? (item.product.serviceCommission * item.quantity)
                : resolveCommissionAmount(item.product.name, price: item.priceAtSale, product: item.product);
            final commRate = item.priceAtSale > 0 ? ((commAmount / item.priceAtSale) * 100.0) : 40.0;

            final record = BarberRecord(
              id: 'REC-${sale.id}',
              branchCode: sale.branchCode ?? 'MAIN',
              customerName: sale.customerName != null && sale.customerName!.isNotEmpty ? sale.customerName! : 'Walk-In Client',
              customerPhone: sale.customerPhone ?? '',
              service: item.product.name,
              serviceCategory: BarberRecord.categorizeService(item.product.name),
              barber: barberName,
              attendant: sale.cashierName,
              price: item.priceAtSale,
              tip: 0.0,
              totalPaid: item.priceAtSale,
              paymentMethod: paymentMethod,
              timestamp: sale.timestamp,
              saleId: sale.id,
              source: 'POS',
              commissionRate: commRate,
              commissionAmount: commAmount,
            );
            newRecords.add(record);
            existingSaleIds.add(sale.id);
            break; // Record per sale
          }
        }
      }

      // 2. Backfill from completed queue items
      for (final q in queue) {
        if (q.status == 'Completed' && !existingQueueIds.contains(q.id)) {
          final qPrice = q.price ?? 50.0;
          final commAmount = resolveCommissionAmount(q.service, price: qPrice);
          final commRate = qPrice > 0 ? ((commAmount / qPrice) * 100.0) : 40.0;

          final record = BarberRecord(
            id: 'REC-${q.id}',
            branchCode: q.branchCode,
            customerName: q.customer,
            customerPhone: q.phone,
            service: q.service,
            serviceCategory: BarberRecord.categorizeService(q.service),
            barber: q.barber,
            attendant: 'Attendant',
            price: qPrice,
            tip: 0.0,
            totalPaid: qPrice,
            paymentMethod: 'Cash',
            timestamp: q.timestamp,
            saleId: q.saleId,
            queueId: q.id,
            appointmentId: q.appointmentId,
            source: q.isAppointment ? 'Appointment' : 'Queue',
            commissionRate: commRate,
            commissionAmount: commAmount,
          );
          newRecords.add(record);
          existingQueueIds.add(q.id);
        }
      }

      if (newRecords.isNotEmpty && mounted) {
        final updated = [...newRecords, ...state]
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = updated;
        await _saveToCache(updated);

        // Sync backfilled items to Supabase asynchronously
        try {
          final connectivity = await Connectivity().checkConnectivity();
          if (!connectivity.contains(ConnectivityResult.none)) {
            try {
              final jsonList = newRecords.map((r) => r.toJson()).toList();
              await SupabaseConfig.client.from('barber_records').upsert(jsonList);
            } catch (_) {
              final dbList = newRecords.map((r) => r.toDbJson()).toList();
              await SupabaseConfig.client.from('barber_records').upsert(dbList);
            }
          }
        } catch (e) {
          debugPrint('Supabase backfill sync notice: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _backfillFromExistingSalesAndQueue: $e');
    } finally {
      _isBackfilling = false;
    }
  }

  /// Resolves the straight fixed commission amount for a service defined by admin in Stock Control
  double resolveCommissionAmount(String serviceName, {double? price, Product? product}) {
    // 1. Direct check on product
    if (product != null && product.serviceCommission > 0) {
      return product.serviceCommission;
    }

    // 2. Query products catalog from Stock Control
    try {
      final products = ref.read(productsFutureProvider).value ?? [];
      final sName = serviceName.trim().toLowerCase();
      for (final p in products) {
        final pName = p.name.trim().toLowerCase();
        if (pName == sName || pName.contains(sName) || sName.contains(pName)) {
          if (p.serviceCommission > 0) {
            return p.serviceCommission;
          }
        }
      }
    } catch (_) {}

    // 3. Query default barber service notifier
    try {
      final services = ref.read(barberServicesProvider);
      final sName = serviceName.trim().toLowerCase();
      for (final s in services) {
        final sn = s.name.trim().toLowerCase();
        if (sn == sName || sn.contains(sName) || sName.contains(sn)) {
          return s.commissionAmount;
        }
      }
    } catch (_) {}

    // 4. Default fallback: GH₵ 20 or price-proportional
    return price != null ? (price >= 50 ? 20.0 : (price * 0.40)) : 20.0;
  }

  double _resolveCommissionPercentage(String serviceName) {
    try {
      final services = ref.read(barberServicesProvider);
      final sName = serviceName.trim().toLowerCase();
      for (final s in services) {
        if (s.name.toLowerCase() == sName || sName.contains(s.name.toLowerCase())) {
          return s.commissionPercentage;
        }
      }
    } catch (_) {}
    return 40.0;
  }

  /// Adds a completed shaving/grooming record permanently with accurate fixed commission
  Future<BarberRecord> recordService({
    required String customerName,
    required String customerPhone,
    required String service,
    required String barber,
    required double price,
    double tip = 0.0,
    String paymentMethod = 'Cash',
    String attendant = 'Staff',
    String? saleId,
    String? queueId,
    String? appointmentId,
    String source = 'Queue',
    String? notes,
    DateTime? timestamp,
    double? commissionRate,
    double? commissionAmount,
    Product? product,
  }) async {
    final String recordId = 'REC-${DateTime.now().millisecondsSinceEpoch}';
    final serviceTime = timestamp ?? DateTime.now();

    final double effectiveComm = commissionAmount ??
        resolveCommissionAmount(service, price: price, product: product);
    final double effectiveRate = commissionRate ??
        (price > 0 ? ((effectiveComm / price) * 100.0) : 40.0);

    final record = BarberRecord(
      id: recordId,
      branchCode: 'MAIN',
      customerName: customerName.trim().isEmpty ? 'Walk-In Client' : customerName.trim(),
      customerPhone: customerPhone.trim(),
      service: service.trim(),
      serviceCategory: BarberRecord.categorizeService(service),
      barber: barber.trim(),
      attendant: attendant.trim(),
      price: price,
      tip: tip,
      totalPaid: price + tip,
      paymentMethod: paymentMethod,
      timestamp: serviceTime,
      saleId: saleId,
      queueId: queueId,
      appointmentId: appointmentId,
      source: source,
      notes: notes?.trim(),
      commissionRate: effectiveRate,
      commissionAmount: effectiveComm,
    );

    // Save locally
    final updatedList = [record, ...state]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = updatedList;
    await _saveToCache(updatedList);

    // Also notify BarberCommissionLog stream
    try {
      ref.read(barberCommissionsProvider.notifier).logCommission(
        BarberCommissionLog.fromRecord(record),
      );
    } catch (_) {}

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        try {
          await SupabaseConfig.client.from('barber_records').upsert(record.toJson());
        } catch (_) {
          await SupabaseConfig.client.from('barber_records').upsert(record.toDbJson());
        }
      }
    } catch (e) {
      debugPrint('Supabase record sync notice: $e');
    }

    return record;
  }

  /// Filters records with multiple criteria
  List<BarberRecord> filter({
    String searchQuery = '',
    String selectedBarber = 'All',
    String? barber,
    String selectedService = 'All',
    String? service,
    String selectedCategory = 'All',
    String? category,
    String selectedDateFilter = 'All Time',
    String? dateFilter,
    DateTimeRange? customDateRange,
    DateTimeRange? customRange,
    String selectedPaymentMethod = 'All',
    String? paymentMethod,
  }) {
    final query = searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final effectiveBarber = barber ?? selectedBarber;
    final effectiveService = service ?? selectedService;
    final effectiveCategory = category ?? selectedCategory;
    final effectiveDateFilter = dateFilter ?? selectedDateFilter;
    final effectiveCustomRange = customRange ?? customDateRange;
    final effectivePayment = paymentMethod ?? selectedPaymentMethod;

    return state.where((record) {
      // 1. Search Query: matches Customer Name, Phone, Barber, Service, or Record/Sale ID
      if (query.isNotEmpty) {
        final matchesCustomer = record.customerName.toLowerCase().contains(query);
        final matchesPhone = record.customerPhone.toLowerCase().contains(query);
        final matchesBarber = record.barber.toLowerCase().contains(query);
        final matchesService = record.service.toLowerCase().contains(query);
        final matchesId = record.id.toLowerCase().contains(query) || (record.saleId?.toLowerCase().contains(query) ?? false);

        if (!matchesCustomer && !matchesPhone && !matchesBarber && !matchesService && !matchesId) {
          return false;
        }
      }

      // 2. Filter by Barber
      if (effectiveBarber != 'All' && effectiveBarber.isNotEmpty) {
        if (!record.barber.toLowerCase().contains(effectiveBarber.toLowerCase())) {
          return false;
        }
      }

      // 3. Filter by Specific Service / Haircut
      if (effectiveService != 'All' && effectiveService.isNotEmpty) {
        if (record.service.toLowerCase() != effectiveService.toLowerCase()) {
          return false;
        }
      }

      // 4. Filter by Category
      if (effectiveCategory != 'All' && effectiveCategory.isNotEmpty) {
        if (record.serviceCategory.toLowerCase() != effectiveCategory.toLowerCase()) {
          return false;
        }
      }

      // 5. Filter by Payment Method
      if (effectivePayment != 'All' && effectivePayment.isNotEmpty) {
        if (record.paymentMethod.toLowerCase() != effectivePayment.toLowerCase()) {
          return false;
        }
      }

      // 6. Filter by Date Range
      final t = record.timestamp;
      if (effectiveDateFilter == 'Today') {
        if (t.year != now.year || t.month != now.month || t.day != now.day) {
          return false;
        }
      } else if (effectiveDateFilter == 'Yesterday') {
        final yesterday = now.subtract(const Duration(days: 1));
        if (t.year != yesterday.year || t.month != yesterday.month || t.day != yesterday.day) {
          return false;
        }
      } else if (effectiveDateFilter == 'This Week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        if (t.isBefore(startOfDay)) {
          return false;
        }
      } else if (effectiveDateFilter == 'This Month') {
        if (t.year != now.year || t.month != now.month) {
          return false;
        }
      } else if ((effectiveDateFilter == 'Custom' || effectiveDateFilter == 'Custom Range') && effectiveCustomRange != null) {
        final start = DateTime(effectiveCustomRange.start.year, effectiveCustomRange.start.month, effectiveCustomRange.start.day);
        final end = DateTime(effectiveCustomRange.end.year, effectiveCustomRange.end.month, effectiveCustomRange.end.day, 23, 59, 59);
        if (t.isBefore(start) || t.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Summarizes performance, commissions, and tips for a specific barber
  BarberCommissionSummary getBarberCommissionSummary(
    String barberName, {
    DateTime? sinceDate,
    DateTimeRange? range,
    String dateFilter = 'All Time',
  }) {
    final filtered = filter(
      barber: barberName,
      dateFilter: range != null ? 'Custom Range' : dateFilter,
      customRange: range,
    ).where((r) {
      if (sinceDate != null && r.timestamp.isBefore(sinceDate)) {
        return false;
      }
      return true;
    }).toList();

    return BarberCommissionSummary.fromRecords(barberName, filtered);
  }

  /// Returns commission summary grouped for all barbers who have records or active roles
  Map<String, BarberCommissionSummary> getAllBarbersCommissionSummary({
    DateTime? sinceDate,
    DateTimeRange? range,
    String dateFilter = 'All Time',
    List<String>? includeBarbers,
  }) {
    final Map<String, BarberCommissionSummary> map = {};
    final allBarberNames = <String>{
      ...?includeBarbers,
      ...state.map((r) => r.barber),
    }.where((b) => b.trim().isNotEmpty).toList()
      ..sort();

    for (final name in allBarberNames) {
      map[name] = getBarberCommissionSummary(
        name,
        sinceDate: sinceDate,
        range: range,
        dateFilter: dateFilter,
      );
    }

    return map;
  }
}

final barberRecordsProvider =
    StateNotifierProvider<BarberRecordsNotifier, List<BarberRecord>>((ref) {
  return BarberRecordsNotifier(ref);
});

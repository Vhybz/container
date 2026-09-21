import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/shift_model.dart';
import '../models/sale_model.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'sale_provider.dart';

class ShiftNotifier extends StateNotifier<ShiftRecord?> {
  final Ref ref;
  static const String _boxName = 'shifts_box';

  ShiftNotifier(this.ref) : super(null) {
    _loadActiveShift();
  }

  Future<void> _loadActiveShift() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawActive = box.get('active_shift');
      if (rawActive != null) {
        state = ShiftRecord.fromJson(jsonDecode(rawActive));
      }
    } catch (e) {
      debugPrint('Error loading active shift: $e');
    }
  }

  Future<void> _saveActiveShift(ShiftRecord? shift) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      if (shift == null) {
        await box.delete('active_shift');
      } else {
        await box.put('active_shift', jsonEncode(shift.toJson()));
      }
    } catch (e) {
      debugPrint('Error saving active shift: $e');
    }
  }

  /// Start a new cashier shift with an opening drawer float
  Future<ShiftRecord> startShift({required double openingFloat}) async {
    final user = ref.read(currentUserProvider);
    final String shiftId = 'SHIFT-${DateTime.now().millisecondsSinceEpoch}';

    final newShift = ShiftRecord(
      id: shiftId,
      branchCode: user?.branchCode ?? 'MAIN',
      cashierId: user?.id ?? 'N/A',
      cashierName: user?.name ?? 'Cashier',
      startTime: DateTime.now(),
      status: 'open',
      openingFloat: openingFloat,
      expectedCashSales: 0.0,
      momoSales: 0.0,
      cardSales: 0.0,
      totalSales: 0.0,
      createdAt: DateTime.now(),
    );

    state = newShift;
    await _saveActiveShift(newShift);

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('shift_records').upsert(newShift.toJson());
      }
    } catch (e) {
      debugPrint('Supabase start shift notice: $e');
    }

    return newShift;
  }

  /// Calculate live sales during the current shift
  Map<String, double> computeLiveShiftTotals() {
    if (state == null) {
      return {'cash': 0.0, 'momo': 0.0, 'card': 0.0, 'total': 0.0};
    }

    final sales = ref.read(saleHistoryProvider);
    final shift = state!;

    final shiftSales = sales.where((s) {
      return s.timestamp.isAfter(shift.startTime.subtract(const Duration(seconds: 2))) &&
          s.status != SaleStatus.cancelled;
    }).toList();

    double cash = 0.0;
    double momo = 0.0;
    double card = 0.0;

    for (final sale in shiftSales) {
      for (final p in sale.payments) {
        if (p.method == PaymentMethod.cash) {
          cash += p.amount;
        } else if (p.method == PaymentMethod.mobileMoney) {
          momo += p.amount;
        } else {
          card += p.amount;
        }
      }
    }

    return {
      'cash': cash,
      'momo': momo,
      'card': card,
      'total': cash + momo + card,
    };
  }

  /// Close shift with physical cash count and calculate cash variance
  Future<ShiftRecord?> closeShift({
    required double actualCashCounted,
    String? notes,
  }) async {
    if (state == null) return null;

    final totals = computeLiveShiftTotals();
    final double cashSales = totals['cash']!;
    final double momoSales = totals['momo']!;
    final double cardSales = totals['card']!;
    final double totalSales = totals['total']!;

    final double expectedTotalCash = state!.openingFloat + cashSales;
    final double variance = actualCashCounted - expectedTotalCash;

    final closedShift = state!.copyWith(
      endTime: DateTime.now(),
      status: 'closed',
      expectedCashSales: cashSales,
      actualCashCounted: actualCashCounted,
      cashVariance: variance,
      momoSales: momoSales,
      cardSales: cardSales,
      totalSales: totalSales,
      notes: notes,
    );

    // Save history in local box
    try {
      final box = await Hive.openBox<String>(_boxName);
      final List rawHistory = box.get('shift_history') != null ? jsonDecode(box.get('shift_history')!) : [];
      rawHistory.insert(0, closedShift.toJson());
      await box.put('shift_history', jsonEncode(rawHistory));
    } catch (e) {
      debugPrint('Error archiving shift: $e');
    }

    // Reset active shift
    state = null;
    await _saveActiveShift(null);

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('shift_records').upsert(closedShift.toJson());
      }
    } catch (e) {
      debugPrint('Supabase close shift notice: $e');
    }

    return closedShift;
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftRecord?>((ref) {
  return ShiftNotifier(ref);
});

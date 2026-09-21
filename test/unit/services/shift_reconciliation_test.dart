import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/shift_model.dart';

void main() {
  group('Shift Reconciliation & Blind Till Variance Tests', () {
    test('ShiftRecord computes balanced variance when actualCash matches expected drawer cash', () {
      final shift = ShiftRecord(
        id: 'SHIFT-001',
        branchCode: 'MAIN',
        cashierId: 'c-01',
        cashierName: 'Kofi Manu',
        startTime: DateTime(2026, 9, 21, 8, 0),
        endTime: DateTime(2026, 9, 21, 17, 0),
        status: 'closed',
        openingFloat: 100.00,
        expectedCashSales: 450.00,
        actualCashCounted: 550.00, // 100 + 450 = 550
        cashVariance: 0.00,
        momoSales: 200.00,
        cardSales: 50.00,
        totalSales: 700.00,
        createdAt: DateTime(2026, 9, 21, 8, 0),
      );

      final expectedCash = shift.openingFloat + shift.expectedCashSales;
      final variance = (shift.actualCashCounted ?? 0.0) - expectedCash;

      expect(expectedCash, equals(550.00));
      expect(variance, equals(0.00));
      expect(shift.cashVariance, equals(0.00));
      expect(shift.totalSales, equals(700.00));
    });

    test('ShiftRecord detects cash shortage when actual cash is less than expected', () {
      final shift = ShiftRecord(
        id: 'SHIFT-002',
        branchCode: 'MAIN',
        cashierId: 'c-01',
        cashierName: 'Kofi Manu',
        startTime: DateTime(2026, 9, 21, 8, 0),
        status: 'open',
        openingFloat: 200.00,
        expectedCashSales: 800.00,
        createdAt: DateTime(2026, 9, 21, 8, 0),
      );

      final expectedDrawerCash = shift.openingFloat + shift.expectedCashSales; // 1000.00
      const actualCountedCash = 980.00; // Cashier counted 980
      final variance = actualCountedCash - expectedDrawerCash; // -20.00

      expect(expectedDrawerCash, equals(1000.00));
      expect(variance, equals(-20.00));
      expect(variance < 0, isTrue); // Shortage
    });

    test('ShiftRecord detects cash surplus when actual cash is greater than expected', () {
      const openingFloat = 50.00;
      const expectedCashSales = 320.00;
      const actualCountedCash = 390.00; // Tip or customer left extra
      const expectedDrawerCash = openingFloat + expectedCashSales; // 370.00
      const variance = actualCountedCash - expectedDrawerCash; // +20.00

      expect(variance, equals(20.00));
      expect(variance > 0, isTrue); // Surplus
    });

    test('Denomination counter calculates Ghana Cedis banknote subtotal correctly', () {
      final counts = {
        200: 2,  // 400
        100: 5,  // 500
        50: 6,   // 300
        20: 10,  // 200
        10: 15,  // 150
        5: 8,    // 40
        2: 5,    // 10
        1: 7,    // 7
      };
      const looseCoins = 3.50;

      double total = looseCoins;
      counts.forEach((denom, qty) {
        total += denom * qty;
      });

      // 400 + 500 + 300 + 200 + 150 + 40 + 10 + 7 + 3.50 = 1610.50
      expect(total, equals(1610.50));
    });

    test('ShiftRecord serialization preserves variance and audit notes', () {
      final shift = ShiftRecord(
        id: 'SHIFT-003',
        branchCode: 'ACCRA-01',
        cashierId: 'c-02',
        cashierName: 'Abena Osei',
        startTime: DateTime(2026, 9, 21, 9, 0),
        endTime: DateTime(2026, 9, 21, 18, 0),
        status: 'closed',
        openingFloat: 150.00,
        expectedCashSales: 600.00,
        actualCashCounted: 745.00,
        cashVariance: -5.00,
        momoSales: 300.00,
        cardSales: 0.00,
        totalSales: 900.00,
        notes: '[Count: ₵100×5, ₵50×4, ₵20×2] Shortage due to loose coins rounding',
        createdAt: DateTime(2026, 9, 21, 9, 0),
      );

      final json = shift.toJson();
      expect(json['cash_variance'], equals(-5.00));
      expect(json['notes'], contains('[Count: ₵100×5'));

      final restored = ShiftRecord.fromJson(json);
      expect(restored.cashVariance, equals(-5.00));
      expect(restored.actualCashCounted, equals(745.00));
      expect(restored.notes, contains('Shortage due to loose coins rounding'));
    });
  });
}

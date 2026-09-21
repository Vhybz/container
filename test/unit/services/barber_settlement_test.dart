import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/barbershop_models.dart';
import 'package:container_business_manager/models/salary_model.dart';
import 'package:container_business_manager/models/expense_model.dart';

void main() {
  group('Barber Daily Commission Settlement Unit Tests', () {
    test('BarberCommissionSummary aggregates services, commissions, and tips correctly', () {
      final records = <BarberRecord>[
        BarberRecord(
          id: 'b-rec-1',
          customerName: 'Kwesi Appiah',
          service: 'Executive Haircut',
          price: 50.00,
          commissionAmount: 20.00,
          tip: 5.00,
          barber: 'King Mojo',
          timestamp: DateTime(2026, 9, 21, 10, 0),
        ),
        BarberRecord(
          id: 'b-rec-2',
          customerName: 'Yaw Boateng',
          service: 'Beard Grooming & Oil',
          price: 30.00,
          commissionAmount: 12.00,
          tip: 0.00,
          barber: 'King Mojo',
          timestamp: DateTime(2026, 9, 21, 11, 30),
        ),
        BarberRecord(
          id: 'b-rec-3',
          customerName: 'Sammy K',
          service: 'Hair Dye / Blackening',
          price: 45.00,
          commissionAmount: 15.00,
          tip: 10.00,
          barber: 'King Mojo',
          timestamp: DateTime(2026, 9, 21, 14, 0),
        ),
      ];

      final summary = BarberCommissionSummary.fromRecords('King Mojo', records);

      expect(summary.totalServices, equals(3));
      expect(summary.grossSales, equals(125.00)); // 50 + 30 + 45
      expect(summary.totalCommission, equals(47.00)); // 20 + 12 + 15
      expect(summary.totalTips, equals(15.00)); // 5 + 0 + 10
      expect(summary.totalEarnings, equals(62.00)); // 47 + 15
    });

    test('Net payout correctly applies deductions for advances taken', () {
      const double totalCommission = 80.00;
      const double tips = 20.00;
      const double baseEarnings = totalCommission + tips; // 100.00
      const double deductions = 25.00; // e.g. advance lunch / transport

      final double netPayout = (baseEarnings - deductions).clamp(0.0, double.infinity);

      expect(netPayout, equals(75.00));
    });

    test('Net payout clamps to 0 when deductions exceed earnings', () {
      const double totalCommission = 30.00;
      const double tips = 0.00;
      const double deductions = 50.00;

      final double netPayout = (totalCommission + tips - deductions).clamp(0.0, double.infinity);

      expect(netPayout, equals(0.00));
    });

    test('SalaryRecord and ExpenseRecord for barber settlement log properly', () {
      final now = DateTime(2026, 9, 21, 18, 0);
      final salaryPayout = SalaryRecord(
        id: 'PAY-BARBER-101',
        userId: 'barber-mojo',
        amount: 75.00,
        isAdvance: false,
        date: now,
        targetMonth: now,
        note: 'Commission Settlement (Today) for King Mojo',
      );

      final expensePayout = ExpenseRecord(
        id: 'EXP-COMM-101',
        title: 'Barber Commission: King Mojo (Today)',
        amount: 75.00,
        category: 'Wages',
        date: now,
        notes: 'Settled Cash payout for 3 services.',
      );

      expect(salaryPayout.amount, equals(75.00));
      expect(salaryPayout.isAdvance, isFalse);
      expect(expensePayout.amount, equals(75.00));
      expect(expensePayout.category, equals('Wages'));

      final salaryJson = salaryPayout.toJson();
      expect(salaryJson['amount'], equals(75.00));
      expect(salaryJson['note'], contains('Commission Settlement'));
    });
  });
}

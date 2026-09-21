import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/barbershop_models.dart';

void main() {
  group('Barber Commission Calculations & Models', () {
    test('standard 40% commission is computed accurately', () {
      final record = BarberRecord(
        id: 'REC-001',
        customerName: 'Kofi Mensah',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        price: 50.0,
        tip: 0.0,
        timestamp: DateTime.now(),
      );

      expect(record.commissionRate, equals(40.0));
      expect(record.effectiveCommission, equals(20.0)); // 50 * 0.40
      expect(record.totalEarnings, equals(20.0));
    });

    test('custom commission rate and tips are factored correctly', () {
      final record = BarberRecord(
        id: 'REC-002',
        customerName: 'Kwame Boateng',
        service: 'Facial Scrub & Steam',
        barber: 'King Mojo',
        price: 60.0,
        tip: 15.0,
        commissionRate: 45.0, // 45% commission
        timestamp: DateTime.now(),
      );

      expect(record.commissionRate, equals(45.0));
      expect(record.effectiveCommission, equals(27.0)); // 60 * 0.45
      expect(record.totalEarnings, equals(42.0)); // 27.0 comm + 15.0 tip
    });

    test('explicit commissionAmount overrides calculation if given', () {
      final record = BarberRecord(
        id: 'REC-003',
        customerName: 'Ama Serwaa',
        service: 'Hair Dye / Blackening',
        barber: 'Stylist Joe',
        price: 45.0,
        tip: 5.0,
        commissionRate: 35.0,
        commissionAmount: 18.0, // Explicit override
        timestamp: DateTime.now(),
      );

      expect(record.effectiveCommission, equals(18.0));
      expect(record.totalEarnings, equals(23.0));
    });

    test('serialization toJson and fromJson preserves commission metadata', () {
      final original = BarberRecord(
        id: 'REC-004',
        customerName: 'Yaw Osei',
        service: 'Beard Grooming & Oil',
        barber: 'King Mojo',
        price: 30.0,
        tip: 8.0,
        commissionRate: 40.0,
        notes: 'Regular customer',
        timestamp: DateTime.parse('2026-09-15T14:30:00Z'),
      );

      final jsonMap = original.toJson();
      expect(jsonMap['commission_rate'], equals(40.0));
      expect(jsonMap['commission_amount'], equals(12.0));
      expect(jsonMap['notes'], contains('__COMM_META__'));

      final restored = BarberRecord.fromJson(jsonMap);
      expect(restored.id, equals(original.id));
      expect(restored.barber, equals('King Mojo'));
      expect(restored.commissionRate, equals(40.0));
      expect(restored.effectiveCommission, equals(12.0));
      expect(restored.tip, equals(8.0));
      expect(restored.totalEarnings, equals(20.0));
      expect(restored.displayNotes, equals('Regular customer'));
    });

    test('legacy JSON without commission fields defaults gracefully to 40%', () {
      final legacyJson = {
        'id': 'REC-LEGACY',
        'customer_name': 'Legacy Client',
        'service': 'Haircut',
        'barber': 'King Mojo',
        'price': 80.0,
        'tip': 10.0,
        'timestamp': '2026-09-10T10:00:00Z',
      };

      final restored = BarberRecord.fromJson(legacyJson);
      expect(restored.commissionRate, equals(40.0));
      expect(restored.effectiveCommission, equals(32.0)); // 80 * 0.40
      expect(restored.totalEarnings, equals(42.0)); // 32 comm + 10 tip
    });

    test('BarberCommissionSummary aggregates services, sales, commissions and tips', () {
      final records = [
        BarberRecord(
          id: 'REC-1',
          customerName: 'Client A',
          service: 'Executive Haircut',
          serviceCategory: 'Haircuts',
          barber: 'King Mojo',
          price: 50.0,
          tip: 10.0,
          timestamp: DateTime.now(),
        ),
        BarberRecord(
          id: 'REC-2',
          customerName: 'Client B',
          service: 'Beard Grooming & Oil',
          serviceCategory: 'Shaves & Beard',
          barber: 'King Mojo',
          price: 30.0,
          tip: 5.0,
          timestamp: DateTime.now(),
        ),
        BarberRecord(
          id: 'REC-3',
          customerName: 'Client C',
          service: 'Kids Haircut',
          serviceCategory: 'Kids Haircut',
          barber: 'King Mojo',
          price: 40.0,
          tip: 0.0,
          timestamp: DateTime.now(),
        ),
      ];

      final summary = BarberCommissionSummary.fromRecords('King Mojo', records);

      expect(summary.totalServices, equals(3));
      expect(summary.grossSales, equals(120.0)); // 50 + 30 + 40
      expect(summary.totalCommission, equals(48.0)); // 20 + 12 + 16 (40% of 120)
      expect(summary.totalTips, equals(15.0)); // 10 + 5 + 0
      expect(summary.totalEarnings, equals(63.0)); // 48 comm + 15 tips
      expect(summary.effectiveCommissionRate, equals(40.0));
      expect(summary.servicesByType['Haircuts'], equals(1));
      expect(summary.servicesByType['Shaves & Beard'], equals(1));
      expect(summary.servicesByType['Kids Haircut'], equals(1));
    });

    test('BarberCommissionLog.fromRecord correctly mirrors BarberRecord', () {
      final record = BarberRecord(
        id: 'REC-LOG-01',
        customerName: 'Nana Kwame',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        price: 50.0,
        tip: 12.0,
        timestamp: DateTime.parse('2026-09-17T12:00:00Z'),
      );

      final log = BarberCommissionLog.fromRecord(record);
      expect(log.id, equals('REC-LOG-01'));
      expect(log.barberName, equals('King Mojo'));
      expect(log.serviceName, equals('Executive Haircut'));
      expect(log.saleAmount, equals(50.0));
      expect(log.commissionEarned, equals(20.0));
      expect(log.tipAmount, equals(12.0));
      expect(log.date, equals(record.timestamp));
    });

    test('BarberService uses fixed commissionAmount rather than percentage calculation', () {
      final service = BarberService(
        id: 'S-FIXED',
        name: 'VIP Shave & Cut',
        price: 70.0,
        durationMinutes: 45,
        commissionAmount: 25.0, // Fixed GHS 25 commission
      );

      expect(service.commissionAmount, equals(25.0));
      // Computed percentage should reflect (25 / 70) * 100
      expect(service.commissionPercentage, closeTo(35.71, 0.01));

      final json = service.toJson();
      expect(json['commission_amount'], equals(25.0));

      final restored = BarberService.fromJson(json);
      expect(restored.commissionAmount, equals(25.0));
    });

    test('Fixed commission is preserved in BarberRecord even when price varies', () {
      // Even if haircut price is discounted to 40 or increased to 60,
      // fixed commission remains exactly 20.0 as defined by admin
      final record = BarberRecord(
        id: 'REC-FIXED',
        customerName: 'Ama Boateng',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        price: 40.0, // discounted price
        commissionAmount: 20.0, // fixed amount defined at stock control
        timestamp: DateTime.now(),
      );

      expect(record.effectiveCommission, equals(20.0));
      expect(record.totalEarnings, equals(20.0));
    });
  });
}

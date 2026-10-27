import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/services/sms_service.dart';

void main() {
  group('Weekly Executive Summary SMS Formatting', () {
    test('sendWeeklySummarySms with empty admin list returns true/false safely', () async {
      final success = await SmsService.sendWeeklySummarySms(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
        weeklySales: 15400.50,
        totalTransactions: 120,
        totalExpenses: 2100.00,
        netProfit: 13300.50,
        paymentBreakdown: {
          'Cash': 8000.00,
          'Mobile Money': 6400.50,
          'Card / Bank': 1000.00,
        },
        sectorBreakdown: {
          'Pharmacy': 6000.00,
          'Barbershop': 3000.00,
          'Tech & Repairs': 2400.50,
          'Retail / Wholesale': 4000.00,
        },
        topPerformer: 'Kwame (GHS 5200)',
        lowStockCount: 3,
        adminPhones: [],
      );

      // With no admin phones provided, returns true as default for loop exhaustion without error
      expect(success, isTrue);
    });
  });
}

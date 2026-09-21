import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/product.dart';

void main() {
  group('FEFO Expiry Logic Tests', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    test('Product with no batchExpiryDate defaults gracefully', () {
      final product = Product(
        id: 'prod-none',
        name: 'Regular Paracetamol',
        retailPrice: 10.0,
        wholesalePrice: 8.0,
        stockQuantity: 100,
        category: 'Pharmacy',
        imageUrl: '',
      );

      expect(product.isExpired, isFalse);
      expect(product.daysUntilExpiry, isNull);
      expect(product.isExpiringCritical, isFalse);
      expect(product.isExpiringWarning, isFalse);
      expect(product.expiryStatus, ExpiryStatus.none);
    });

    test('Product with past expiry date is flagged as expired', () {
      final pastDate = today.subtract(const Duration(days: 5));
      final product = Product(
        id: 'prod-expired',
        name: 'Expired Amoxicillin',
        retailPrice: 25.0,
        wholesalePrice: 20.0,
        stockQuantity: 15,
        category: 'Pharmacy',
        imageUrl: '',
        batchExpiryDate: pastDate,
        batchNumber: 'BATCH-EX-001',
      );

      expect(product.isExpired, isTrue);
      expect(product.daysUntilExpiry, lessThan(0));
      expect(product.isExpiringCritical, isFalse);
      expect(product.isExpiringWarning, isFalse);
      expect(product.expiryStatus, ExpiryStatus.expired);
    });

    test('Product expiring in 15 days is flagged as critical FEFO priority', () {
      final criticalDate = today.add(const Duration(days: 15));
      final product = Product(
        id: 'prod-crit',
        name: 'Cough Syrup (Near Expiry)',
        retailPrice: 18.0,
        wholesalePrice: 15.0,
        stockQuantity: 8,
        category: 'Pharmacy',
        imageUrl: '',
        batchExpiryDate: criticalDate,
        batchNumber: 'BATCH-CRIT-99',
      );

      expect(product.isExpired, isFalse);
      expect(product.daysUntilExpiry, equals(15));
      expect(product.isExpiringCritical, isTrue);
      expect(product.isExpiringWarning, isFalse);
      expect(product.expiryStatus, ExpiryStatus.critical);
    });

    test('Product expiring in 60 days is flagged with warning status', () {
      final warnDate = today.add(const Duration(days: 60));
      final product = Product(
        id: 'prod-warn',
        name: 'Vitamin C 500mg',
        retailPrice: 12.0,
        wholesalePrice: 10.0,
        stockQuantity: 40,
        category: 'Pharmacy',
        imageUrl: '',
        batchExpiryDate: warnDate,
      );

      expect(product.isExpired, isFalse);
      expect(product.daysUntilExpiry, equals(60));
      expect(product.isExpiringCritical, isFalse);
      expect(product.isExpiringWarning, isTrue);
      expect(product.expiryStatus, ExpiryStatus.warning);
    });

    test('Product expiring in 180 days is flagged as good', () {
      final goodDate = today.add(const Duration(days: 180));
      final product = Product(
        id: 'prod-good',
        name: 'Antimalarial Artemether',
        retailPrice: 35.0,
        wholesalePrice: 30.0,
        stockQuantity: 100,
        category: 'Pharmacy',
        imageUrl: '',
        batchExpiryDate: goodDate,
      );

      expect(product.isExpired, isFalse);
      expect(product.daysUntilExpiry, equals(180));
      expect(product.isExpiringCritical, isFalse);
      expect(product.isExpiringWarning, isFalse);
      expect(product.expiryStatus, ExpiryStatus.good);
    });

    test('FEFO sorting arranges earliest expiring products first', () {
      final prod1 = Product(
        id: '1',
        name: 'Batch C (90 days)',
        retailPrice: 10,
        wholesalePrice: 8,
        imageUrl: '',
        category: 'Pharmacy',
        batchExpiryDate: today.add(const Duration(days: 90)),
      );
      final prod2 = Product(
        id: '2',
        name: 'Batch A (10 days)',
        retailPrice: 10,
        wholesalePrice: 8,
        imageUrl: '',
        category: 'Pharmacy',
        batchExpiryDate: today.add(const Duration(days: 10)),
      );
      final prod3 = Product(
        id: '3',
        name: 'Batch B (30 days)',
        retailPrice: 10,
        wholesalePrice: 8,
        imageUrl: '',
        category: 'Pharmacy',
        batchExpiryDate: today.add(const Duration(days: 30)),
      );
      final prod4 = Product(
        id: '4',
        name: 'Non-dated Item',
        retailPrice: 10,
        wholesalePrice: 8,
        imageUrl: '',
        category: 'Pharmacy',
      );

      final list = [prod1, prod4, prod2, prod3];

      list.sort((a, b) {
        if (a.batchExpiryDate != null && b.batchExpiryDate != null) {
          return a.batchExpiryDate!.compareTo(b.batchExpiryDate!);
        }
        if (a.batchExpiryDate != null) return -1;
        if (b.batchExpiryDate != null) return 1;
        return a.name.compareTo(b.name);
      });

      expect(list[0].id, equals('2')); // 10 days
      expect(list[1].id, equals('3')); // 30 days
      expect(list[2].id, equals('1')); // 90 days
      expect(list[3].id, equals('4')); // No expiry date
    });
  });
}

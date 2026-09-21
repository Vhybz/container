import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/sale_model.dart';
import 'package:container_business_manager/models/product.dart';

void main() {
  group('SaleRecord & Financial Calculation Tests', () {
    final testProduct = Product(
      id: 'p1',
      name: 'Amoxicillin 500mg',
      retailPrice: 20.0,
      wholesalePrice: 15.0,
      costPrice: 10.0,
      imageUrl: '',
      category: 'Antibiotics',
      stockQuantity: 50.0,
      unit: 'packs',
    );

    test('SaleItem total and discount calculation', () {
      final saleItem = SaleItem(
        product: testProduct,
        quantity: 3.0,
        priceAtSale: 20.0,
        originalPrice: 25.0,
      );

      expect(saleItem.total, equals(60.0)); // 3 * 20.0
      expect(saleItem.discount, equals(15.0)); // (25 - 20) * 3
    });

    test('SaleRecord balance and debt calculation', () {
      final item = SaleItem(
        product: testProduct,
        quantity: 2.0,
        priceAtSale: 20.0,
        originalPrice: 20.0,
      );

      final saleRecord = SaleRecord(
        id: 'sale-1001',
        items: [item],
        totalAmount: 40.0,
        totalDiscount: 0.0,
        totalCost: 20.0,
        payments: [
          PaymentDetail(
            method: PaymentMethod.cash,
            amount: 25.0,
          )
        ],
        status: SaleStatus.completed,
        timestamp: DateTime.now(),
        cashierId: 'staff-01',
        cashierName: 'Kwame Mensah',
      );

      expect(saleRecord.totalAmount, equals(40.0));
      expect(saleRecord.amountPaid, equals(25.0));
      expect(saleRecord.balance, equals(15.0)); // 40 - 25 = 15 debt
    });
  });
}

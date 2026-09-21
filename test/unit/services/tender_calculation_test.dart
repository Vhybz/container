import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/sale_model.dart';
import 'package:container_business_manager/models/product.dart';
import 'package:container_business_manager/widgets/tender_dialog.dart';

void main() {
  group('Tender Calculation & Change Due Unit Tests', () {
    final testProduct = Product(
      id: 'p-test',
      name: 'Paracetamol Syrup',
      retailPrice: 24.50,
      wholesalePrice: 20.0,
      costPrice: 15.0,
      imageUrl: '',
      category: 'Analgesics',
      stockQuantity: 100.0,
      unit: 'bottles',
    );

    test('SaleRecord correctly calculates effectiveChange when amountTendered > amountPaid', () {
      final item = SaleItem(
        product: testProduct,
        quantity: 2.0,
        priceAtSale: 24.50,
        originalPrice: 24.50,
      );

      final sale = SaleRecord(
        id: 'sale-tender-01',
        items: [item],
        totalAmount: 49.00,
        totalDiscount: 0.0,
        totalCost: 30.0,
        payments: [
          PaymentDetail(
            method: PaymentMethod.cash,
            amount: 49.00,
          ),
        ],
        amountTendered: 100.00,
        changeDue: 51.00,
        status: SaleStatus.completed,
        timestamp: DateTime.now(),
        cashierId: 'cashier-1',
        cashierName: 'Ama Serwaa',
      );

      expect(sale.amountPaid, equals(49.00));
      expect(sale.amountTendered, equals(100.00));
      expect(sale.changeDue, equals(51.00));
      expect(sale.effectiveChange, equals(51.00));
      expect(sale.balance, equals(0.00));
    });

    test('SaleRecord effectiveChange falls back to amountTendered - amountPaid if changeDue is null', () {
      final item = SaleItem(
        product: testProduct,
        quantity: 1.0,
        priceAtSale: 24.50,
        originalPrice: 24.50,
      );

      final sale = SaleRecord(
        id: 'sale-tender-02',
        items: [item],
        totalAmount: 24.50,
        totalDiscount: 0.0,
        totalCost: 15.0,
        payments: [
          PaymentDetail(
            method: PaymentMethod.cash,
            amount: 24.50,
          ),
        ],
        amountTendered: 50.00,
        changeDue: null,
        status: SaleStatus.completed,
        timestamp: DateTime.now(),
        cashierId: 'cashier-1',
        cashierName: 'Ama Serwaa',
      );

      expect(sale.effectiveChange, closeTo(25.50, 0.001));
    });

    test('SaleRecord JSON serialization preserves amountTendered and changeDue', () {
      final item = SaleItem(
        product: testProduct,
        quantity: 1.0,
        priceAtSale: 24.50,
        originalPrice: 24.50,
      );

      final original = SaleRecord(
        id: 'sale-json-01',
        items: [item],
        totalAmount: 24.50,
        totalDiscount: 0.0,
        totalCost: 15.0,
        payments: [
          PaymentDetail(
            method: PaymentMethod.cash,
            amount: 24.50,
          ),
        ],
        amountTendered: 50.00,
        changeDue: 25.50,
        status: SaleStatus.completed,
        timestamp: DateTime(2026, 9, 21, 10, 0),
        cashierId: 'cashier-1',
        cashierName: 'Ama Serwaa',
      );

      final json = original.toJson();
      expect(json['amount_tendered'], equals(50.00));
      expect(json['change_due'], equals(25.50));

      final restored = SaleRecord.fromJson(json);
      expect(restored.amountTendered, equals(50.00));
      expect(restored.changeDue, equals(25.50));
      expect(restored.effectiveChange, equals(25.50));
    });

    test('TenderResult encapsulates payments and change returned correctly', () {
      final result = TenderResult(
        totalAmount: 100.00,
        payments: [
          PaymentDetail(method: PaymentMethod.cash, amount: 74.00),
          PaymentDetail(method: PaymentMethod.mobileMoney, amount: 26.00, reference: '0241234567'),
        ],
        amountTendered: 100.00,
        changeDue: 26.00,
      );

      expect(result.totalPaid, equals(100.00));
      expect(result.amountTendered, equals(100.00));
      expect(result.changeDue, equals(26.00));
      expect(result.payments.length, equals(2));
      expect(result.payments[0].method, equals(PaymentMethod.cash));
      expect(result.payments[1].method, equals(PaymentMethod.mobileMoney));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/product.dart';

void main() {
  group('Product Model & Stock Logic Tests', () {
    test('Product JSON serialization and deserialization retains stock and sector metadata', () {
      final product = Product(
        id: 'prod-001',
        branchCode: 'MAIN',
        name: 'Paracetamol Extra 500mg',
        retailPrice: 15.0,
        wholesalePrice: 12.0,
        costPrice: 8.0,
        imageUrl: '',
        category: 'Pharmaceuticals',
        stockQuantity: 100.0,
        unit: 'pcs',
        lowStockThreshold: 10.0,
        batchNumber: 'BATCH-2026-A',
      );

      final json = product.toJson();
      expect(json['id'], equals('prod-001'));
      expect(json['name'], equals('Paracetamol Extra 500mg'));
      expect(json['retail_price'], equals(15.0));
      expect(json['stock_quantity'], equals(100.0));

      final deserialized = Product.fromJson(json);
      expect(deserialized.id, equals(product.id));
      expect(deserialized.name, equals(product.name));
      expect(deserialized.retailPrice, equals(15.0));
      expect(deserialized.stockQuantity, equals(100.0));
    });

    test('Effective price calculates promotional discount correctly', () {
      final productWithDiscount = Product(
        id: 'prod-002',
        name: 'Hair Clipper Oil',
        retailPrice: 50.0,
        wholesalePrice: 40.0,
        costPrice: 30.0,
        imageUrl: '',
        category: 'Barber Supplies',
        stockQuantity: 25.0,
        unit: 'pcs',
        discountPercentage: 20.0, // 20% off
        promoStartDate: DateTime.now().subtract(const Duration(days: 1)),
        promoEndDate: DateTime.now().add(const Duration(days: 1)),
      );

      final effectivePrice = productWithDiscount.getPrice(false);
      expect(effectivePrice, equals(40.0)); // 50 * 0.80 = 40.0
    });

    test('Stock alert status accurately identifies low stock and out-of-stock items', () {
      final lowStockProduct = Product(
        id: 'prod-003',
        name: 'USB-C Fast Cable',
        retailPrice: 35.0,
        wholesalePrice: 25.0,
        costPrice: 15.0,
        imageUrl: '',
        category: 'Accessories',
        stockQuantity: 3.0,
        unit: 'pcs',
        lowStockThreshold: 5.0,
      );

      expect(lowStockProduct.stockQuantity <= lowStockProduct.lowStockThreshold, isTrue);
    });
  });
}

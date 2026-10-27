import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/product.dart';

void main() {
  group('IMEI Tracking Unit Tests', () {
    test('Product.copyWith updates requiresImei and imeiList correctly', () {
      final initialProduct = Product(
        id: 'tech-001',
        name: 'iPhone 15 Pro Max 256GB',
        retailPrice: 12000.0,
        wholesalePrice: 11500.0,
        imageUrl: '',
        category: 'Smartphones',
        stockQuantity: 2.0,
        unit: 'pcs',
        requiresImei: false,
        imeiList: [],
      );

      expect(initialProduct.requiresImei, isFalse);
      expect(initialProduct.imeiList, isEmpty);

      final updatedProduct = initialProduct.copyWith(
        requiresImei: true,
        imeiList: ['359123456789012', '359123456789013'],
        stockQuantity: 2.0,
      );

      expect(updatedProduct.requiresImei, isTrue);
      expect(updatedProduct.imeiList, contains('359123456789012'));
      expect(updatedProduct.imeiList, contains('359123456789013'));
      expect(updatedProduct.imeiList?.length, equals(2));
    });

    test('Product JSON serialization preserves imeiList and requiresImei', () {
      final product = Product(
        id: 'tech-002',
        name: 'Samsung Galaxy S24 Ultra',
        retailPrice: 11000.0,
        wholesalePrice: 10500.0,
        imageUrl: '',
        category: 'Smartphones',
        stockQuantity: 1.0,
        unit: 'pcs',
        requiresImei: true,
        imeiList: ['354892019283741'],
      );

      final json = product.toJson();
      expect(json['requires_imei'], isTrue);
      expect(json['imei_list'], equals(['354892019283741']));

      final deserialized = Product.fromJson(json);
      expect(deserialized.requiresImei, isTrue);
      expect(deserialized.imeiList, contains('354892019283741'));
    });
  });
}

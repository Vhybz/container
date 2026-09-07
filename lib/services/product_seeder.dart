import '../core/uuid_utils.dart';
import '../models/product.dart';
import 'product_service.dart';
import 'user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProductSeeder {
  final Ref ref;
  ProductSeeder(this.ref);

  Future<void> seedProducts() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.branchCode == null) return;

    final service = ref.read(productServiceProvider);
    
    final List<Map<String, List<Map<String, dynamic>>>> multiSectorData = [
      {
        'PHARMACY': [
          {'name': 'Amoxicillin 500mg', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Paracetamol Extra 500mg', 'price': 10.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Ibuprofen 400mg', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Metformin 850mg', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Omeprazole 20mg', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Vitamin C 1000mg Chewable', 'price': 18.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'First Aid Kit', 'price': 85.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Hand Sanitizer 500ml', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': false},
        ]
      },
      {
        'BARBERSHOP': [
          {'name': 'Executive Haircut', 'price': 50.0, 'unit': 'service', 'isService': true},
          {'name': 'Beard Grooming & Oil', 'price': 30.0, 'unit': 'service', 'isService': true},
          {'name': 'Hair Dye / Blackening', 'price': 45.0, 'unit': 'service', 'isService': true},
          {'name': 'Facial Scrub & Steam', 'price': 60.0, 'unit': 'service', 'isService': true},
          {'name': 'Kids Haircut', 'price': 30.0, 'unit': 'service', 'isService': true},
          {'name': 'Premium Hair Gel (150g)', 'price': 25.0, 'unit': 'pcs', 'isService': false},
          {'name': 'Beard Growth Oil (50ml)', 'price': 40.0, 'unit': 'pcs', 'isService': false},
        ]
      },
      {
        'PHONE & ACCESSORIES': [
          {'name': 'iPhone 15 Pro 128GB', 'price': 14500.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Samsung Galaxy S24 Ultra', 'price': 15200.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Google Pixel 8 Pro', 'price': 8500.0, 'unit': 'unit', 'requiresImei': true},
          {'name': '20W USB-C Fast Charger', 'price': 180.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'MagSafe Clear Case', 'price': 120.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': '9D Curved Tempered Glass', 'price': 50.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'iPhone Screen Repair (Labor + Part)', 'price': 1200.0, 'unit': 'service', 'isService': true},
        ]
      }
    ];

    // Get existing products to avoid duplicates
    final existingProductsAsync = ref.read(productsFutureProvider);
    final existingNames = existingProductsAsync.value?.map((p) => p.name.toLowerCase()).toSet() ?? {};

    for (var categoryMap in multiSectorData) {
      final category = categoryMap.keys.first;
      final productList = categoryMap.values.first;

      for (var item in productList) {
        final String name = item['name'];
        if (existingNames.contains(name.toLowerCase())) continue;

        final double price = (item['price'] as num).toDouble();
        final String unit = item['unit'] ?? 'pcs';
        final bool isService = item['isService'] ?? false;
        final bool requiresPrescription = item['requiresPrescription'] ?? false;
        final bool requiresImei = item['requiresImei'] ?? false;

        final String validUuid = UuidUtils.generate();

        final product = Product(
          id: validUuid,
          branchCode: user.branchCode,
          name: name,
          retailPrice: price,
          wholesalePrice: price,
          costPrice: price * 0.7,
          imageUrl: '', 
          category: category,
          stockQuantity: isService ? 999.0 : 50.0,
          unit: unit,
          isUnlimited: isService,
          isService: isService,
          requiresPrescription: requiresPrescription,
          requiresImei: requiresImei,
        );
        
        await service.addProduct(product);
      }
    }
  }
}

final productSeederProvider = Provider<ProductSeeder>((ref) => ProductSeeder(ref));

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
          {'name': 'Antfan Tab', 'category': 'Antimalarial', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Lufant DS', 'category': 'Antimalarial', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Artfan Suspension', 'category': 'Antimalarial', 'price': 30.0, 'unit': 'bot', 'requiresPrescription': true},
          {'name': 'Lufart suspension', 'category': 'Antimalarial', 'price': 32.0, 'unit': 'bot', 'requiresPrescription': true},
          {'name': 'Amoxicillin caps', 'category': 'Antibiotic', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Ciprofloxacin', 'category': 'Antibiotic', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Azithromycin', 'category': 'Antibiotic', 'price': 45.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Cefuroxime', 'category': 'Antibiotic', 'price': 50.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Norfloxacin 200mg', 'category': 'Antibiotic', 'price': 28.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Chloramphenicol', 'category': 'Antibiotic', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Metronidazole sirop', 'category': 'Antibiotic', 'price': 22.0, 'unit': 'bot', 'requiresPrescription': true},
          {'name': 'Peladol extra', 'category': 'Analgesic', 'price': 12.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'ESKcol', 'category': 'Analgesic', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Eskadol nyte', 'category': 'Analgesic', 'price': 18.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Drastin APC', 'category': 'Analgesic', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Parabary tab', 'category': 'Analgesic', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Basecam', 'category': 'NSAID', 'price': 20.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Cap celecoxib 200mg', 'category': 'NSAID', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Prednisolone', 'category': 'NSAID', 'price': 20.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Coldrs... caps', 'category': 'Cough & Cold', 'price': 18.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Kwik action', 'category': 'Cough & Cold', 'price': 10.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Shaltoux', 'category': 'Cough & Cold', 'price': 22.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Ronak Inhaler', 'category': 'Cough & Cold', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Skydipin 30', 'category': 'Cardiovascular', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Losartan 50', 'category': 'Cardiovascular', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Losartan Potassium', 'category': 'Cardiovascular', 'price': 32.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Magnesium trisilicate sup', 'category': 'Gastrointestinal', 'price': 20.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Magacid susp.', 'category': 'Gastrointestinal', 'price': 20.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Zerocid susp.', 'category': 'Gastrointestinal', 'price': 22.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Liver salt', 'category': 'Gastrointestinal', 'price': 15.0, 'unit': 'pack', 'requiresPrescription': false},
          {'name': 'Lydia Secure', 'category': 'Contraceptive', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Contra-72', 'category': 'Contraceptive', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Postinor 2', 'category': 'Contraceptive', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Kiss condom', 'category': 'Contraceptive', 'price': 10.0, 'unit': 'pack', 'requiresPrescription': false},
          {'name': 'GML-Apeti', 'category': 'Supplement', 'price': 30.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Riddles Mud Syrup', 'category': 'Supplement', 'price': 25.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Ayrton mult. Syrup', 'category': 'Supplement', 'price': 28.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Dynoell Syrup', 'category': 'Supplement', 'price': 25.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Haemoglobin sirop', 'category': 'Supplement', 'price': 35.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Eppace Junior Syrp', 'category': 'Supplement', 'price': 28.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Polyfer forte syrup', 'category': 'Supplement', 'price': 38.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Samalin adult sirop', 'category': 'Supplement', 'price': 30.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Samalin junior', 'category': 'Supplement', 'price': 25.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Tres-orix', 'category': 'Supplement', 'price': 35.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Cyfen syrup', 'category': 'Supplement', 'price': 28.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Bricovit forte', 'category': 'Supplement', 'price': 32.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Lechna syrup', 'category': 'Supplement', 'price': 25.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Cehtone syrup', 'category': 'Supplement', 'price': 28.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Cyproidine', 'category': 'Supplement', 'price': 30.0, 'unit': 'bot', 'requiresPrescription': false},
          {'name': 'Abytone forte caps', 'category': 'Supplement', 'price': 35.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Ronfit Gel', 'category': 'Topical & Gel', 'price': 25.0, 'unit': 'tube', 'requiresPrescription': false},
          {'name': 'Ronfit forte', 'category': 'Topical & Gel', 'price': 28.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Chlordiazepoxide', 'category': 'Sedative', 'price': 40.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Zudrex tab', 'category': 'General Medication', 'price': 12.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Letacam', 'category': 'General Medication', 'price': 15.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Mixtel', 'category': 'General Medication', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Fembase extra', 'category': 'General Medication', 'price': 22.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Asmanol', 'category': 'General Medication', 'price': 30.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Tracaram', 'category': 'General Medication', 'price': 20.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Cibro-C', 'category': 'General Medication', 'price': 20.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Pecbore', 'category': 'General Medication', 'price': 25.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Ronloz 100', 'category': 'General Medication', 'price': 40.0, 'unit': 'pcs', 'requiresPrescription': true},
          {'name': 'Treedar', 'category': 'General Medication', 'price': 22.0, 'unit': 'pcs', 'requiresPrescription': false},
          {'name': 'Let-2in simp', 'category': 'General Medication', 'price': 20.0, 'unit': 'bot', 'requiresPrescription': false},
        ]
      },
      {
        'BARBERSHOP': [
          {'name': 'Executive Haircut', 'category': 'Haircut Services', 'price': 50.0, 'unit': 'service', 'isService': true},
          {'name': 'Kids Haircut', 'category': 'Haircut Services', 'price': 30.0, 'unit': 'service', 'isService': true},
          {'name': 'Beard Grooming & Oil', 'category': 'Grooming & Treatments', 'price': 30.0, 'unit': 'service', 'isService': true},
          {'name': 'Hair Dye / Blackening', 'category': 'Grooming & Treatments', 'price': 45.0, 'unit': 'service', 'isService': true},
          {'name': 'Facial Scrub & Steam', 'category': 'Grooming & Treatments', 'price': 60.0, 'unit': 'service', 'isService': true},
          {'name': 'Premium Hair Gel (150g)', 'category': 'Care Products', 'price': 25.0, 'unit': 'pcs', 'isService': false},
          {'name': 'Beard Growth Oil (50ml)', 'category': 'Care Products', 'price': 40.0, 'unit': 'pcs', 'isService': false},
        ]
      },
      {
        'PHONE & ACCESSORIES': [
          // Smartphones
          {'name': 'iPhone 15 Pro 128GB', 'category': 'Smartphones', 'price': 14500.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Samsung Galaxy S24 Ultra', 'category': 'Smartphones', 'price': 15200.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Google Pixel 8 Pro', 'category': 'Smartphones', 'price': 8500.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Xiaomi Redmi Note 13 Pro', 'category': 'Smartphones', 'price': 3200.0, 'unit': 'unit', 'requiresImei': true},
          {'name': 'Tecno Camon 30 Premier', 'category': 'Smartphones', 'price': 2800.0, 'unit': 'unit', 'requiresImei': true},

          // Chargers & Power
          {'name': '20W USB-C Fast Charger', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': '65W GaN Desktop Fast Charger', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': '20,000mAh Power Bank (22.5W)', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': '15W MagSafe Wireless Pad', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Type-C to Lightning Cable 1m', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': '100W Braided Type-C Cable', 'category': 'Chargers & Power', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Cases & Protection
          {'name': 'MagSafe Clear Case', 'category': 'Cases & Protection', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Shockproof Silicone Armor Case', 'category': 'Cases & Protection', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Leather Flip Wallet Case', 'category': 'Cases & Protection', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Screen Protectors
          {'name': '9D Curved Tempered Glass', 'category': 'Screen Protectors', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Anti-Spy Privacy Tempered Glass', 'category': 'Screen Protectors', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'HD Camera Lens Protector', 'category': 'Screen Protectors', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Audio & Sound
          {'name': 'Wireless ANC Noise Cancelling Earbuds', 'category': 'Audio & Sound', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'AirPods Pro 2nd Gen', 'category': 'Audio & Sound', 'price': 0.0, 'unit': 'pcs', 'requiresImei': true},
          {'name': 'Sports Bluetooth Neckband', 'category': 'Audio & Sound', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Portable Mini Bluetooth Speaker', 'category': 'Audio & Sound', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Smart Wearables
          {'name': 'Smartwatch Series 9 (AMOLED)', 'category': 'Smart Wearables', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Fitness Tracker Band 8', 'category': 'Smart Wearables', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Mounts & Holders
          {'name': 'Magnetic Car Air Vent Mount', 'category': 'Mounts & Holders', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},
          {'name': 'Adjustable Desktop Phone Stand', 'category': 'Mounts & Holders', 'price': 0.0, 'unit': 'pcs', 'requiresImei': false},

          // Repairs & Services
          {'name': 'iPhone Screen Repair (Labor + Part)', 'category': 'Repairs & Services', 'price': 1200.0, 'unit': 'service', 'isService': true},
          {'name': 'Battery Replacement Service', 'category': 'Repairs & Services', 'price': 450.0, 'unit': 'service', 'isService': true},
          {'name': 'Charging Port Repair', 'category': 'Repairs & Services', 'price': 300.0, 'unit': 'service', 'isService': true},
          {'name': 'Software Flashing & Unlocking', 'category': 'Repairs & Services', 'price': 250.0, 'unit': 'service', 'isService': true},
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
        final String itemCategory = item['category'] ?? category;

        final String validUuid = UuidUtils.generate();

        final bool isPharmItem = category == 'PHARMACY' || requiresPrescription;
        final double initialStockQuantity = isService ? 999.0 : (isPharmItem ? 0.0 : 50.0);

        final product = Product(
          id: validUuid,
          branchCode: user.branchCode,
          name: name,
          retailPrice: price,
          wholesalePrice: price,
          costPrice: price * 0.7,
          imageUrl: '', 
          category: itemCategory,
          stockQuantity: initialStockQuantity,
          unit: unit,
          isUnlimited: isService,
          isService: isService,
          requiresPrescription: requiresPrescription,
          requiresImei: requiresImei,
          piecesPerPack: isPharmItem ? 10.0 : null,
          packPrice: isPharmItem ? (price * 10.0) : null,
        );
        
        await service.addProduct(product);
      }
    }

    // Ensure all existing drug stock quantities are set to zero as requested
    await resetPharmacyStockToZero();

    // Ensure tech accessories are set to 50pcs @ 0.0 GHS for admin pricing
    await resetTechAccessoriesToUnpriced50pcs();
  }

  Future<void> resetPharmacyStockToZero() async {
    final products = ref.read(productsFutureProvider).value ?? [];
    for (var p in products) {
      final cat = p.category.toUpperCase();
      final isPharm = p.requiresPrescription || 
          cat.contains('PHARM') || cat.contains('DRUG') || cat.contains('MED') ||
          cat.contains('ANTIBIOTIC') || cat.contains('ANTIMALARIAL') || cat.contains('ANALGESIC') ||
          cat.contains('NSAID') || cat.contains('COUGH') || cat.contains('COLD') || cat.contains('CARDIOVASCULAR') ||
          cat.contains('GASTRO') || cat.contains('CONTRACEPTIVE') || cat.contains('SUPPLEMENT') ||
          cat.contains('TOPICAL') || cat.contains('SEDATIVE') || cat.contains('GENERAL MEDICATION');

      if (isPharm) {
        final double pcsPerPack = (p.piecesPerPack != null && p.piecesPerPack! > 0) ? p.piecesPerPack! : 10.0;
        final double correctPackPrice = (p.packPrice == null || p.packPrice == p.retailPrice)
            ? (p.retailPrice * pcsPerPack)
            : p.packPrice!;

        final updated = p.copyWith(
          stockQuantity: 0.0,
          piecesPerPack: pcsPerPack,
          packPrice: correctPackPrice,
        );
        await ref.read(productsFutureProvider.notifier).updateProduct(updated);
      }
    }
  }

  Future<void> resetTechAccessoriesToUnpriced50pcs() async {
    final products = ref.read(productsFutureProvider).value ?? [];
    for (var p in products) {
      final cat = p.category.toUpperCase();
      final isTechAccessory = cat.contains('CHARGER') ||
          cat.contains('CASE') ||
          cat.contains('SCREEN') ||
          cat.contains('AUDIO') ||
          cat.contains('WEARABLE') ||
          cat.contains('MOUNT') ||
          cat.contains('ACCESSOR') ||
          cat.contains('SMARTPHONE');

      if (isTechAccessory && !p.isService) {
        final updatedProduct = p.copyWith(
          retailPrice: 0.0,
          wholesalePrice: 0.0,
          costPrice: 0.0,
          stockQuantity: 50.0,
        );
        await ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
      }
    }
  }
}

final productSeederProvider = Provider<ProductSeeder>((ref) => ProductSeeder(ref));

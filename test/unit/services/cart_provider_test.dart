import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:container_business_manager/models/product.dart';
import 'package:container_business_manager/services/cart_provider.dart';
import 'package:container_business_manager/services/pos_navigator_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartNotifier POS Switch & Cart Clearing Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    final testProduct = Product(
      id: 'prod-001',
      name: 'iPhone 15 Case',
      retailPrice: 50.0,
      wholesalePrice: 40.0,
      costPrice: 20.0,
      imageUrl: '',
      category: 'Accessories',
      stockQuantity: 10.0,
      unit: 'pcs',
    );

    test('normalizePosId accurately recognizes routes and canonical identifiers', () {
      expect(CartNotifier.normalizePosId('/cashier'), equals('cashier'));
      expect(CartNotifier.normalizePosId('cashier'), equals('cashier'));

      expect(CartNotifier.normalizePosId('/pharmacy/pos'), equals('pharmacy'));
      expect(CartNotifier.normalizePosId('pharmacy'), equals('pharmacy'));
      expect(CartNotifier.normalizePosId('pharmacist'), equals('pharmacy'));

      expect(CartNotifier.normalizePosId('/barbershop/pos'), equals('barbershop'));
      expect(CartNotifier.normalizePosId('barbershop'), equals('barbershop'));
      expect(CartNotifier.normalizePosId('barber'), equals('barbershop'));

      expect(CartNotifier.normalizePosId('/tech/pos'), equals('tech'));
      expect(CartNotifier.normalizePosId('tech'), equals('tech'));
      expect(CartNotifier.normalizePosId('tech_shop'), equals('tech'));

      // Non-POS routes return null
      expect(CartNotifier.normalizePosId('/admin'), isNull);
      expect(CartNotifier.normalizePosId('/settings'), isNull);
      expect(CartNotifier.normalizePosId('/pharmacy'), isNull); // Dashboard, not POS
      expect(CartNotifier.normalizePosId(null), isNull);
    });

    test('Clears cart when switching from one POS to a different POS', () {
      final cartNotifier = container.read(cartProvider.notifier);

      // 1. Enter Tech POS
      cartNotifier.registerPos('/tech/pos');
      expect(cartNotifier.activePos, equals('tech'));

      // 2. Add item to cart and enable wholesale mode
      cartNotifier.addItem(testProduct, 2.0, true);
      container.read(isWholesaleProvider.notifier).state = true;
      expect(container.read(cartProvider).length, equals(1));
      expect(container.read(isWholesaleProvider), isTrue);

      // 3. Switch to Pharmacy POS -> Cart must be cleared and wholesale reset
      cartNotifier.registerPos('/pharmacy/pos');
      expect(cartNotifier.activePos, equals('pharmacy'));
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(isWholesaleProvider), isFalse);
    });

    test('Does NOT clear cart when staying in or returning to the same POS', () {
      final cartNotifier = container.read(cartProvider.notifier);

      // 1. Enter Barbershop POS
      cartNotifier.registerPos('/barbershop/pos');
      expect(cartNotifier.activePos, equals('barbershop'));

      // 2. Add item to cart
      cartNotifier.addItem(testProduct, 1.0, false);
      expect(container.read(cartProvider).length, equals(1));

      // 3. Re-register the same POS (e.g. rebuild or page re-focus)
      cartNotifier.registerPos('/barbershop/pos');
      expect(cartNotifier.activePos, equals('barbershop'));
      expect(container.read(cartProvider).length, equals(1));

      // 4. Same POS with canonical id
      cartNotifier.registerPos('barbershop');
      expect(container.read(cartProvider).length, equals(1));
    });

    test('Switching POS with empty cart updates activePos smoothly without errors', () {
      final cartNotifier = container.read(cartProvider.notifier);

      cartNotifier.registerPos('/cashier');
      expect(cartNotifier.activePos, equals('cashier'));
      expect(container.read(cartProvider).isEmpty, isTrue);

      cartNotifier.registerPos('/tech/pos');
      expect(cartNotifier.activePos, equals('tech'));
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('PosNavigatorObserver triggers cart clearing on route transitions', () {
      final observer = container.read(posNavigatorObserverProvider);
      final cartNotifier = container.read(cartProvider.notifier);

      // Push Tech POS
      final techRoute = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/tech/pos'),
      );
      observer.didPush(techRoute, null);
      expect(cartNotifier.activePos, equals('tech'));

      // Add item in Tech POS
      cartNotifier.addItem(testProduct, 1.0, false);
      expect(container.read(cartProvider).length, equals(1));

      // Replace with Cashier POS (e.g. sidebar navigation)
      final cashierRoute = MaterialPageRoute(
        builder: (_) => const SizedBox(),
        settings: const RouteSettings(name: '/cashier'),
      );
      observer.didReplace(newRoute: cashierRoute, oldRoute: techRoute);

      expect(cartNotifier.activePos, equals('cashier'));
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref? _ref;
  CartNotifier([this._ref]) : super([]);

  String? _activePos;
  String? get activePos => _activePos;

  /// Normalizes a route or identifier to canonical POS string:
  /// 'cashier', 'pharmacy', 'barbershop', 'tech'
  static String? normalizePosId(String? routeOrId) {
    if (routeOrId == null) return null;
    final clean = routeOrId.split('?').first.trim().toLowerCase();
    if (clean == '/cashier' || clean == 'cashier') return 'cashier';
    if (clean == '/pharmacy/pos' || clean == 'pharmacy' || clean == 'pharmacist') return 'pharmacy';
    if (clean == '/barbershop/pos' || clean == 'barbershop' || clean == 'barber') return 'barbershop';
    if (clean == '/tech/pos' || clean == 'tech' || clean == 'tech_shop' || clean == 'techshop') return 'tech';
    return null;
  }

  /// Registers which POS is active.
  /// If switching to a DIFFERENT POS, automatically clears the cart
  /// and resets wholesale mode.
  void registerPos(String posRouteOrId) {
    final normalized = normalizePosId(posRouteOrId);
    if (normalized == null) return;

    if (_activePos != null && _activePos != normalized) {
      if (state.isNotEmpty) {
        debugPrint('[CartNotifier] Switching POS from "$_activePos" to "$normalized": clearing ${state.length} cart items');
        clear();
      }
      _ref?.read(isWholesaleProvider.notifier).state = false;
    }
    _activePos = normalized;
  }

  void addItem(Product product, double quantity, bool isWholesale, {String? imei}) {
    final price = product.getPrice(isWholesale);
    final basePrice = isWholesale ? product.wholesalePrice : product.retailPrice;
    state = [...state, CartItem(product: product, quantity: quantity, priceAtSale: price, originalPrice: basePrice, imei: imei)];
  }

  void addItemWithCustomPrice(Product product, double quantity, double customPrice, double originalPrice, {String? imei}) {
    state = [...state, CartItem(product: product, quantity: quantity, priceAtSale: customPrice, originalPrice: originalPrice, imei: imei)];
  }

  void removeItem(int index) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i]
    ];
  }

  void updateQuantity(int index, double newQuantity) {
    if (index < 0 || index >= state.length) return;
    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }
    final current = state[index];
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          CartItem(
            product: current.product,
            quantity: newQuantity,
            priceAtSale: current.priceAtSale,
            originalPrice: current.originalPrice,
            imei: current.imei,
          )
        else
          state[i]
    ];
  }

  void clear() {
    state = [];
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.total);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier(ref);
});

// Provider to track if we are in Wholesale mode
final isWholesaleProvider = StateProvider<bool>((ref) => false);

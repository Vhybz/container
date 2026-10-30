import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/uuid_utils.dart';
import '../models/product.dart';
import '../models/tech_shop_models.dart';
import 'tech_shop_service.dart';
import 'supabase_product_service.dart';
import 'user_provider.dart';
import 'audit_service.dart';
import 'offline_sync_service.dart';
import '../models/system_models.dart';
import '../core/supabase_config.dart';

abstract class ProductService {
  Future<List<Product>> getProducts(String? branchCode);
  Future<Product> getProductById(String id);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> updateStock(String id, double newQuantity);
  Future<void> applyPromotion(String id, double percentage, DateTime? start, DateTime? end, PromoTarget target, PromoCustomerTarget customerTarget);
  Future<String?> uploadProductImage(Uint8List bytes, String fileName);
  Stream<List<Product>> watchProducts(String? branchCode);
}

final productServiceProvider = Provider<ProductService>((ref) {
  return SupabaseProductService();
});

class ProductNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductService _service;
  final Ref ref;
  StreamSubscription<List<Product>>? _subscription;

  ProductNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // 0. Load from local Hive cache immediately for offline support
    _loadFromCache();

    // 1. Watch current user and restart subscription if branch changes
    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        _startSubscription();
      }
    });

    // 2. Background Heartbeat: Silent refresh logic every 3 seconds
    ref.listen(liveHeartbeatProvider, (_, _) {
      // Stock alerts moved to NotificationNotifier to break circular dependency
    });
    
    _startSubscription();
  }

  void _loadFromCache() {
    try {
      final box = Hive.box(OfflineSyncService.productsBoxName);
      if (box.isNotEmpty) {
        final List<Product> cached = box.values
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        state = AsyncValue.data(cached);
        debugPrint('Product Engine: ${cached.length} products loaded from local cache.');
      }
    } catch (e) {
      debugPrint('Product Engine Cache Error: $e');
    }
  }

  void _saveToCache(List<Product> products) {
    try {
      if (products.isEmpty && (state.value?.isNotEmpty ?? false)) return;

      final box = Hive.box(OfflineSyncService.productsBoxName);
      box.clear();
      for (var p in products) {
        box.put(p.id, p.toJson());
      }
    } catch (e) {
      debugPrint('Product Engine Save Error: $e');
    }
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final String? branchCode = (user.branchCode != null && user.branchCode!.trim().isNotEmpty)
          ? user.branchCode!.trim()
          : null;

      // 1. Initial Fresh Fetch (Prioritize Network)
      _fetchFreshProducts(branchCode);

      // 2. Start Real-time Stream
      _subscription = _service.watchProducts(branchCode).listen(
        (products) {
          _applyPendingAndSetState(products);
          _saveToCache(products);
        },
        onError: (e, st) {
          if (kIsWeb) {
            debugPrint('Product Stream Error: $e');
          } else {
            debugPrint('Product Stream Connection Error: $e');
          }
          if (!state.hasValue) {
             state = AsyncValue.error(e, st);
          }
        },
        cancelOnError: false,
      );
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> _fetchFreshProducts(String? branchCode) async {
    try {
      var products = await _service.getProducts(branchCode);
      // Fallback: If products is empty for a specific branch, pull all global/master products so POS is never blank
      if (products.isEmpty && branchCode != null && branchCode.isNotEmpty) {
        final masterProducts = await _service.getProducts(null);
        if (masterProducts.isNotEmpty) {
          products = masterProducts;
          debugPrint('Product Engine: Branch "$branchCode" returned 0 products. Loaded ${masterProducts.length} master products as fallback.');
        }
      }
      _applyPendingAndSetState(products);
      _saveToCache(products);
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Product Fetch Error (Web): $e');
      } else {
        debugPrint('Product Fetch Error (Offline): $e');
      }
    }
  }

  void _applyPendingAndSetState(List<Product> remoteProducts) {
    final pendingProducts = OfflineSyncService.getPendingItems('UPDATE_PRODUCT')
        .map((json) => Product.fromJson(json))
        .toList();
        
    final pendingDeletes = OfflineSyncService.getPendingItems('DELETE_PRODUCT')
        .map((json) => json['id'] as String)
        .toList();

    final Map<String, Product> allMap = {};
    
    // 1. Current State
    state.whenData((products) {
      for (var p in products) {
        if (!pendingDeletes.contains(p.id)) {
          allMap[p.id] = p;
        }
      }
    });
    
    // 2. Remote Cloud
    for (var p in remoteProducts) {
      if (!pendingDeletes.contains(p.id)) {
        allMap[p.id] = p;
      }
    }
    
    // 3. Local Queue
    for (var p in pendingProducts) {
      if (!pendingDeletes.contains(p.id)) {
        allMap[p.id] = p;
      }
    }

    final finalProducts = allMap.values.toList();
    finalProducts.sort((a, b) => a.name.compareTo(b.name));

    state = AsyncValue.data(finalProducts);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadProducts() async {
    final user = ref.read(currentUserProvider);
    await _fetchFreshProducts(user?.branchCode);
  }

  Future<void> addProduct(Product product) async {
    final user = ref.read(currentUserProvider);
    final productWithBranch = (product.branchCode != null && product.branchCode!.isNotEmpty)
        ? product
        : product.copyWith(branchCode: user?.branchCode);
    
    if (productWithBranch.imeiList != null && productWithBranch.imeiList!.isNotEmpty) {
      final imeiNotifier = ref.read(imeiInventoryProvider.notifier);
      final existingImeis = ref.read(imeiInventoryProvider).map((r) => r.imei).toSet();
      for (final imei in productWithBranch.imeiList!) {
        final trimmed = imei.trim();
        if (trimmed.isNotEmpty && !existingImeis.contains(trimmed)) {
          imeiNotifier.registerIMEI(
            IMEIRecord(
              imei: trimmed,
              deviceModel: productWithBranch.name,
              status: 'In Stock',
              warrantyDurationMonths: 12,
            ),
          );
        }
      }
    }

    state.whenData((products) {
      final newList = [...products.where((p) => p.id != productWithBranch.id), productWithBranch];
      state = AsyncValue.data(newList);
      _saveToCache(newList);
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.addProduct(productWithBranch);
      } else {
        await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: productWithBranch.toJson());
      }
    } catch (e) {
      await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: productWithBranch.toJson());
    }
  }

  Future<void> updateProduct(Product updatedProduct) async {
    try {
      final oldProduct = state.value?.firstWhere((p) => p.id == updatedProduct.id);
      
      await AuditService.log(
        ref: ref,
        action: 'PRODUCT_UPDATED',
        entityType: 'PRODUCT',
        entityId: updatedProduct.id,
        oldData: oldProduct?.toJson(),
        newData: updatedProduct.toJson(),
      );

      if (updatedProduct.imeiList != null && updatedProduct.imeiList!.isNotEmpty) {
        final imeiNotifier = ref.read(imeiInventoryProvider.notifier);
        final existingImeis = ref.read(imeiInventoryProvider).map((r) => r.imei).toSet();
        for (final imei in updatedProduct.imeiList!) {
          final trimmed = imei.trim();
          if (trimmed.isNotEmpty && !existingImeis.contains(trimmed)) {
            imeiNotifier.registerIMEI(
              IMEIRecord(
                imei: trimmed,
                deviceModel: updatedProduct.name,
                status: 'In Stock',
                warrantyDurationMonths: 12,
              ),
            );
          }
        }
      }

      state.whenData((products) {
        final newList = products.map((p) => p.id == updatedProduct.id ? updatedProduct : p).toList();
        state = AsyncValue.data(newList);
        _saveToCache(newList);
      });

      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.updateProduct(updatedProduct);
      } else {
        await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: updatedProduct.toJson());
      }
    } catch (e) {
      await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: updatedProduct.toJson());
    }
  }

  Future<void> deleteProduct(String id) async {
    state.whenData((products) {
      final newList = products.where((p) => p.id != id).toList();
      state = AsyncValue.data(newList);
      _saveToCache(newList);
    });

    try {
      final connectivity = kIsWeb ? [ConnectivityResult.wifi] : await Connectivity().checkConnectivity();
      if (kIsWeb || !connectivity.contains(ConnectivityResult.none)) {
        await _service.deleteProduct(id);
      } else {
        await OfflineSyncService.addToQueue(actionType: 'DELETE_PRODUCT', data: {'id': id});
      }
    } catch (e) {
      if (!kIsWeb) {
        await OfflineSyncService.addToQueue(actionType: 'DELETE_PRODUCT', data: {'id': id});
      } else {
        rethrow;
      }
    }
  }

  Future<void> restoreProduct(String id) async {
    state.whenData((products) async {
      final updated = products.map((p) => p.id == id ? p.copyWith(isDeleted: false) : p).toList();
      state = AsyncValue.data(updated);
      
      final product = updated.firstWhere((p) => p.id == id);
      await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: product.toJson());
    });
  }

  Future<void> updateStock(
    String id, 
    double quantityChange, {
    String reason = 'ADJUSTMENT', 
    String? referenceId,
    List<String>? newImeis,
    bool? requiresImei,
  }) async {
    final products = state.value;
    final now = DateTime.now();
    final user = ref.read(currentUserProvider);

    try {
      Product? product;
      if (products != null) {
        product = products.where((p) => p.id == id).firstOrNull;
      }
      if (product == null) {
        try {
          product = await _service.getProductById(id);
        } catch (e) {
          debugPrint('Unable to fetch product $id from network (offline): $e');
          return;
        }
      }

      double currentDailyAdded = product.dailyStockAdded;
      if (product.lastStockUpdate != null) {
        final lastUpdate = product.lastStockUpdate!;
        if (lastUpdate.year != now.year || lastUpdate.month != now.month || lastUpdate.day != now.day) {
          currentDailyAdded = 0;
        }
      }

      final newQuantity = product.stockQuantity + quantityChange;
      final newDailyAdded = quantityChange > 0 ? (currentDailyAdded + quantityChange) : currentDailyAdded;
      
      final List<String> currentImeis = List<String>.from(product.imeiList ?? []);
      if (newImeis != null && newImeis.isNotEmpty) {
        final imeiNotifier = ref.read(imeiInventoryProvider.notifier);
        final existingImeis = ref.read(imeiInventoryProvider).map((r) => r.imei).toSet();
        for (final imei in newImeis) {
          final trimmed = imei.trim();
          if (trimmed.isNotEmpty) {
            if (!currentImeis.contains(trimmed)) {
              currentImeis.add(trimmed);
            }
            if (!existingImeis.contains(trimmed)) {
              imeiNotifier.registerIMEI(
                IMEIRecord(
                  imei: trimmed,
                  deviceModel: product.name,
                  status: 'In Stock',
                  warrantyDurationMonths: 12,
                ),
              );
            }
          }
        }
      }
      final bool updatedRequiresImei = requiresImei ?? (product.requiresImei || currentImeis.isNotEmpty);

      final updatedProduct = product.copyWith(
        stockQuantity: newQuantity,
        dailyStockAdded: newDailyAdded,
        lastStockUpdate: now,
        imeiList: currentImeis,
        requiresImei: updatedRequiresImei,
      );

      // 1. OPTIMISTIC UI: Update local state & cache FIRST
      if (products != null) {
        final updatedList = products.map((p) => p.id == id ? updatedProduct : p).toList();
        state = AsyncValue.data(updatedList);
        _saveToCache(updatedList);
      }

      // 2. REMOTE SYNC WITH OFFLINE FALLBACK
      try {
        final connectivity = await Connectivity().checkConnectivity();
        if (!connectivity.contains(ConnectivityResult.none)) {
          try {
            await SupabaseConfig.client.rpc('increment_stock', params: {
              'p_id': id,
              'p_amount': quantityChange,
            });
          } catch (rpcError) {
            debugPrint('Product Engine increment_stock RPC notice: $rpcError');
          }
          
          final updatePayload = <String, dynamic>{
            'stock_quantity': newQuantity,
            'daily_stock_added': updatedProduct.dailyStockAdded,
            'last_stock_update': updatedProduct.lastStockUpdate?.toIso8601String(),
          };
          if (newImeis != null || requiresImei != null) {
            updatePayload['imei_list'] = updatedProduct.imeiList;
            updatePayload['requires_imei'] = updatedProduct.requiresImei;
          }

          await SupabaseConfig.client
              .from('products')
              .update(updatePayload)
              .eq('id', id);

          try {
            final historyEntry = StockHistory(
              id: UuidUtils.generate(),
              branchCode: user?.branchCode,
              productId: id,
              changeAmount: quantityChange,
              newQuantity: newQuantity,
              reason: reason,
              referenceId: referenceId,
              timestamp: now,
            );
            await SupabaseConfig.client.from('stock_history').insert(historyEntry.toJson());
          } catch (_) {}
        } else {
          await OfflineSyncService.addToQueue(
            actionType: 'UPDATE_PRODUCT_STOCK',
            data: {
              'id': id,
              'change_amount': quantityChange,
              'timestamp': now.toIso8601String(),
            },
          );
          await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: updatedProduct.toJson());
        }
      } catch (networkError) {
        debugPrint('Stock sync failed (offline fallback active): $networkError');
        await OfflineSyncService.addToQueue(
          actionType: 'UPDATE_PRODUCT_STOCK',
          data: {
            'id': id,
            'change_amount': quantityChange,
            'timestamp': now.toIso8601String(),
          },
        );
        await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: updatedProduct.toJson());
      }
      
      try {
        await AuditService.log(
          ref: ref,
          action: 'STOCK_ADJUSTED',
          entityType: 'PRODUCT',
          entityId: id,
          newData: {'change': quantityChange, 'new_total': newQuantity, 'reason': reason, ...? (newImeis != null ? {'added_imeis': newImeis} : null)},
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('updateStock error: $e');
    }
  }

  Future<void> applyPromotion(double percentage, DateTime start, DateTime end, PromoTarget target, PromoCustomerTarget customerTarget, {List<String>? selectedIds}) async {
    state.whenData((products) async {
      final productsToUpdate = selectedIds == null 
          ? products 
          : products.where((p) => selectedIds.contains(p.id)).toList();
      
      try {
        for (var p in productsToUpdate) {
          final data = {
            'discount_percentage': percentage,
            'promo_start': start.toIso8601String(),
            'promo_end': end.toIso8601String(),
            'promo_target': target.name,
            'promo_customer_target': customerTarget.name,
          };
          await OfflineSyncService.addToQueue(actionType: 'PROMOTION', data: {'id': p.id, 'data': data});
        }
        
        state = AsyncValue.data(products.map((p) {
          if (selectedIds == null || selectedIds.contains(p.id)) {
            return p.copyWith(
              discountPercentage: percentage,
              promoStartDate: start,
              promoEndDate: end,
              promoTarget: target,
              promoCustomerTarget: customerTarget,
            );
          }
          return p;
        }).toList());
      } catch (e) {
        debugPrint('Apply promotion error: $e');
      }
    });
  }

  Future<void> clearPromotions() async {
    state.whenData((products) async {
      try {
        for (var p in products) {
          if (p.discountPercentage > 0) {
            final data = {
              'discount_percentage': 0,
              'promo_start': null,
              'promo_end': null,
              'promo_target': PromoTarget.both.name,
              'promo_customer_target': PromoCustomerTarget.all.name,
            };
            await OfflineSyncService.addToQueue(actionType: 'PROMOTION', data: {'id': p.id, 'data': data});
          }
        }
        state = AsyncValue.data(products.map((p) => p.copyWith(
          discountPercentage: 0,
          promoStartDate: null,
          promoEndDate: null,
        )).toList());
      } catch (e) {
        debugPrint('Clear promotion error: $e');
      }
    });
  }

  Future<void> removePromotion(String productId) async {
    state.whenData((products) async {
      try {
        final data = {
          'discount_percentage': 0,
          'promo_start': null,
          'promo_end': null,
          'promo_target': PromoTarget.both.name,
          'promo_customer_target': PromoCustomerTarget.all.name,
        };
        await OfflineSyncService.addToQueue(actionType: 'PROMOTION', data: {'id': productId, 'data': data});

        state = AsyncValue.data(products.map((p) => p.id == productId ? p.copyWith(
          discountPercentage: 0,
          promoStartDate: null,
          promoEndDate: null,
        ) : p).toList());
      } catch (e) {
        debugPrint('Remove promotion error: $e');
      }
    });
  }

  Future<void> setUnlimitedStatus(bool isUnlimited, {List<String>? selectedIds}) async {
    state.whenData((products) async {
      final productsToUpdate = selectedIds == null 
          ? products 
          : products.where((p) => selectedIds.contains(p.id)).toList();
      
      try {
        for (var p in productsToUpdate) {
          final updatedProduct = p.copyWith(isUnlimited: isUnlimited);
          await OfflineSyncService.addToQueue(actionType: 'UPDATE_PRODUCT', data: updatedProduct.toJson());
        }
        state = AsyncValue.data(products.map((p) => (selectedIds == null || selectedIds.contains(p.id)) ? p.copyWith(isUnlimited: isUnlimited) : p).toList());
      } catch (e) {
        debugPrint('Set unlimited status error: $e');
      }
    });
  }

  Future<void> clearAllStock() async {
    state.whenData((products) async {
      try {
        for (var p in products) {
          await OfflineSyncService.addToQueue(
            actionType: 'UPDATE_PRODUCT_STOCK',
            data: {
              'id': p.id,
              'change_amount': -p.stockQuantity,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        state = AsyncValue.data(products.map((p) => p.copyWith(stockQuantity: 0)).toList());
      } catch (e) {
        debugPrint('Clear all stock error: $e');
      }
    });
  }

  Future<String?> uploadImage(Uint8List bytes, String fileName) {
    return _service.uploadProductImage(bytes, fileName);
  }
}

final productsFutureProvider = StateNotifierProvider<ProductNotifier, AsyncValue<List<Product>>>((ref) {
  return ProductNotifier(ref.watch(productServiceProvider), ref);
});

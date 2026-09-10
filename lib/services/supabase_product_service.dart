import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/product.dart';
import 'product_service.dart';
import '../core/supabase_config.dart';

class SupabaseProductService implements ProductService {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<List<Product>> getProducts(String? branchCode) async {
    try {
      var query = _client.from('products').select();
      
      if (branchCode != null) {
        // Show products for this branch OR global products (null branch_code)
        query = query.or('branch_code.eq.$branchCode,branch_code.is.null');
      }
      
      final response = await query.eq('is_deleted', false);
      
      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Product> getProductById(String id) async {
    final response = await _client
        .from('products')
        .select()
        .eq('id', id)
        .single();
    
    return Product.fromJson(response);
  }

  @override
  Future<void> addProduct(Product product) async {
    await _client.from('products').insert(product.toJson());
  }

  @override
  Future<void> updateProduct(Product product) async {
    await _client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _client
        .from('products')
        .delete()
        .eq('id', id);
  }

  @override
  Future<void> updateStock(String id, double newQuantity) async {
    // This is still useful for absolute overrides (Admin editing stock)
    await _client
        .from('products')
        .update({'stock_quantity': newQuantity})
        .eq('id', id);
  }

  // Add an atomic increment method using the RPC defined in SUPABASE_SETUP.md
  Future<void> incrementStock(String id, double amount) async {
    await _client.rpc('increment_stock', params: {
      'p_id': id,
      'p_amount': amount,
    });
  }

  @override
  Future<void> applyPromotion(String id, double percentage, DateTime? start, DateTime? end, PromoTarget target, PromoCustomerTarget customerTarget) async {
    await _client
        .from('products')
        .update({
          'discount_percentage': percentage,
          'promo_start': start?.toIso8601String(),
          'promo_end': end?.toIso8601String(),
          'promo_target': target.name,
          'promo_customer_target': customerTarget.name,
        })
        .eq('id', id);
  }

  @override
  Future<String?> uploadProductImage(Uint8List bytes, String fileName) async {
    try {
      final storage = _client.storage.from('product-images');
      final path = 'products/$fileName';
      
      // Upload using uploadBinary for Uint8List
      await storage.uploadBinary(
        path, 
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      // Return the public URL
      final publicUrl = storage.getPublicUrl(path);
      if (publicUrl.isNotEmpty) return publicUrl;
    } catch (e) {
      debugPrint('Storage Upload Warning (falling back to Base64 data URL): $e');
    }
    // Fallback: Convert to Base64 Data URL so the image update never fails!
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  @override
  Stream<List<Product>> watchProducts(String? branchCode) {
    // Supabase stream filters are simple (eq only). 
    // To support "this branch OR global", we fetch all and filter in Dart,
    // OR we could stream without the branch filter if we want global visibility.
    final query = _client.from('products').stream(primaryKey: ['id']);
    
    return query.map((data) => data
            .map((json) => Product.fromJson(json))
            .where((p) => !p.isDeleted)
            .where((p) {
              if (branchCode == null) return true; // Admin sees all
              return p.branchCode == branchCode || p.branchCode == null;
            })
            .toList());
  }
}

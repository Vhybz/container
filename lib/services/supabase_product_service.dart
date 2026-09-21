import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/product.dart';
import 'product_service.dart';
import 'supabase_base_service.dart';

class SupabaseProductService extends SupabaseBaseService implements ProductService {
  @override
  List<String> get riskyColumns => [
    'daily_stock_added', 'last_stock_update', 'imei_list', 'batch_expiry_date', 
    'batch_number', 'is_service', 'requires_prescription', 'requires_imei',
    'pieces_per_pack', 'pack_price', 'number_of_boxes', 'packs_per_box', 'box_price'
  ];

  @override
  Future<List<Product>> getProducts(String? branchCode) async {
    try {
      var query = client.from('products').select();
      
      if (branchCode != null) {
        query = query.or('branch_code.eq.$branchCode,branch_code.is.null');
      }
      
      final response = await query.eq('is_deleted', false).order('name', ascending: true);
      return (response as List).map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Product> getProductById(String id) async {
    final response = await client
        .from('products')
        .select()
        .eq('id', id)
        .single();
    
    return Product.fromJson(response);
  }

  @override
  Future<void> addProduct(Product product) async {
    await robustOperation('products', product.toJson());
  }

  @override
  Future<void> updateProduct(Product product) async {
    await robustOperation('products', product.toJson(), isUpdate: true, updateId: product.id);
  }

  @override
  Future<void> deleteProduct(String id) async {
    await client.from('products').delete().eq('id', id);
  }

  @override
  Future<void> updateStock(String id, double newQuantity) async {
    await client.from('products').update({'stock_quantity': newQuantity}).eq('id', id);
  }

  Future<void> incrementStock(String id, double amount) async {
    await client.rpc('increment_stock', params: {
      'p_id': id,
      'p_amount': amount,
    });
  }

  @override
  Future<void> applyPromotion(String id, double percentage, DateTime? start, DateTime? end, PromoTarget target, PromoCustomerTarget customerTarget) async {
    await client.from('products').update({
      'discount_percentage': percentage,
      'promo_start': start?.toIso8601String(),
      'promo_end': end?.toIso8601String(),
      'promo_target': target.name,
      'promo_customer_target': customerTarget.name,
    }).eq('id', id);
  }

  @override
  Future<String?> uploadProductImage(Uint8List bytes, String fileName) async {
    try {
      final storage = client.storage.from('product-images');
      final path = 'products/$fileName';
      
      await storage.uploadBinary(
        path, 
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      return storage.getPublicUrl(path);
    } catch (e) {
      debugPrint('Storage Upload Warning (falling back to Base64 data URL): $e');
    }
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  @override
  Stream<List<Product>> watchProducts(String? branchCode) {
    // Custom stream logic for products to handle the "branch OR global" requirement
    return client.from('products').stream(primaryKey: ['id'])
        .map((data) => data
            .map((json) => Product.fromJson(json))
            .where((p) => !p.isDeleted)
            .where((p) {
              if (branchCode == null) return true;
              return p.branchCode == branchCode || p.branchCode == null;
            })
            .toList());
  }
}

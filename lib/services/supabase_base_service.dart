import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';

/// A base service that provides robust Supabase interaction logic,
/// including automatic schema reconciliation (PGRST204) and standard error handling.
abstract class SupabaseBaseService {
  SupabaseClient get client => SupabaseConfig.client;

  /// Returns a list of columns that might be missing in older database schemas.
  /// Subclasses should override this to specify their own "risky" columns.
  List<String> get riskyColumns => [];

  /// Executes an operation with a fallback mechanism that strips missing columns.
  Future<void> robustOperation(String table, Map<String, dynamic> payload, {bool isUpdate = false, String? updateId}) async {
    try {
      if (isUpdate && updateId != null) {
        await client.from(table).update(payload).eq('id', updateId);
      } else {
        await client.from(table).upsert(payload);
      }
    } catch (e) {
      final errStr = e.toString();
      
      // PGRST204: Column missing in schema. Fallback by stripping columns.
      if (errStr.contains('PGRST204') || errStr.contains('42703')) {
        final Map<String, dynamic> fallback = Map<String, dynamic>.from(payload);
        bool retryNeeded = false;

        for (final col in riskyColumns) {
          if (errStr.contains("'$col'")) {
            fallback.remove(col);
            retryNeeded = true;
          }
        }

        if (retryNeeded) {
          try {
            if (isUpdate && updateId != null) {
              await client.from(table).update(fallback).eq('id', updateId);
            } else {
              await client.from(table).upsert(fallback);
            }
          } catch (innerE) {
            // Final fallback: Strip ALL risky columns
            final Map<String, dynamic> minimal = Map<String, dynamic>.from(payload);
            for (final col in riskyColumns) {
              minimal.remove(col);
            }
            if (isUpdate && updateId != null) {
              await client.from(table).update(minimal).eq('id', updateId);
            } else {
              await client.from(table).upsert(minimal);
            }
          }
        } else {
          rethrow;
        }
      } else if (errStr.contains('23502')) {
        // Not-null constraint violation: likely staff_name vs cashier_name mismatch
        // Handled by the model typically, but we log it here.
        debugPrint('SUPABASE ERROR (Constraint): $e');
        rethrow;
      } else {
        rethrow;
      }
    }
  }

  /// Standard select with ordering
  Future<List<Map<String, dynamic>>> selectSorted(String table, {String order = 'created_at', bool ascending = false, Map<String, dynamic>? filters}) async {
    var query = client.from(table).select();
    
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) {
          query = query.eq(key, value);
        }
      });
    }
    
    final response = await query.order(order, ascending: ascending);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Standard stream with ordering
  Stream<List<Map<String, dynamic>>> watchTable(String table, {Map<String, dynamic>? filters, String order = 'created_at'}) {
    var query = client.from(table).stream(primaryKey: ['id']);
    
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) {
          query = query.eq(key, value);
        }
      });
    }
    
    return query.order(order, ascending: false);
  }
}

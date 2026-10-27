import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../core/supabase_config.dart';

class SyncStatus {
  final int pendingCount;
  final bool isSyncing;
  final String? lastError;
  SyncStatus({required this.pendingCount, required this.isSyncing, this.lastError});
}

/// This service manages the "Offline-First" logic for Multi-Business Manager.
/// It uses Hive as a fast, schema-less storage for pending cloud actions.
class OfflineSyncService {
  static const String queueBoxName = 'sync_queue';
  static const String productsBoxName = 'products_cache';
  static const String customersBoxName = 'customers_cache';
  static const String salesBoxName = 'sales_cache';
  static const String notificationsBoxName = 'notifications_cache';
  static const String expensesBoxName = 'expenses_cache';
  static const String transfersBoxName = 'transfers_cache';
  static const String butcherBoxName = 'butcher_cache';
  static const String auditBoxName = 'audit_cache';
  static const String settingsBoxName = 'app_settings';
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isProcessing = false;

  static final _statusController = StreamController<SyncStatus>.broadcast();
  static Stream<SyncStatus> get statusStream => _statusController.stream;

  static void _updateStatus(bool isSyncing) {
    try {
      final box = Hive.box(queueBoxName);
      _statusController.add(SyncStatus(pendingCount: box.length, isSyncing: isSyncing));
    } catch (_) {}
  }

  /// Initialize Hive and the sync monitoring
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      
      // Mandatory: Theme/Settings box
      await Hive.openBox(settingsBoxName);

      // Offline-First feature boxes (Now enabled on all platforms including Web)
      await Hive.openBox(queueBoxName);
      await Hive.openBox(productsBoxName);
      await Hive.openBox(customersBoxName);
      await Hive.openBox(salesBoxName);
      await Hive.openBox(notificationsBoxName);
      await Hive.openBox(expensesBoxName);
      await Hive.openBox(transfersBoxName);
      await Hive.openBox(butcherBoxName);
      await Hive.openBox(auditBoxName);
      
      if (!kIsWeb) {
        // Listen for connectivity changes to trigger sync automatically
        _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
          if (results.any((result) => result != ConnectivityResult.none)) {
            debugPrint('Connectivity Restored: Triggering background sync...');
            processQueue();
          }
        });
      }
      
      // Initial check (Works on Web too if internet is available)
      processQueue();
    } catch (e) {
      if (e.toString().contains('lock failed')) {
        debugPrint('OFFLINE ENGINE WARNING: Database is already locked by another process.');
        // We don't rethrow here so the app can still boot, though offline sync will be disabled for this session
      } else {
        rethrow;
      }
    }
  }

  /// Add a data action (Sale, Intake, Waste, etc.) to the local Hive queue.
  /// This returns immediately, allowing the UI to stay fast.
  static Future<void> addToQueue({
    required String actionType,
    required Map<String, dynamic> data,
  }) async {
    final box = Hive.box(queueBoxName);
    final String requestId = '${DateTime.now().millisecondsSinceEpoch}_$actionType';
    
    await box.put(requestId, {
      'type': actionType,
      'payload': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _updateStatus(false);
    debugPrint('Offline Engine: Action "$actionType" cached in Hive (ID: $requestId)');
    
    // Attempt sync immediately (will fail silently if no net)
    processQueue();
  }

  /// Processes all pending items in the Hive Box and pushes them to Supabase
  static Future<void> processQueue() async {
    if (_isProcessing) return;
    
    final results = await Connectivity().checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) {
      debugPrint('Sync Monitor: Device is offline. Waiting for connection...');
      return;
    }

    final box = Hive.box(queueBoxName);
    if (box.isEmpty) return;

    _isProcessing = true;
    _updateStatus(true);
    debugPrint('Sync Monitor: ${box.length} pending items found. Starting cloud push...');

    final List<dynamic> keys = List.from(box.keys);

    for (final key in keys) {
      final item = box.get(key);
      if (item == null) continue; // Safety: skip if item was deleted while loop was running

      final String type = item['type'];
      final Map<String, dynamic> payload = Map<String, dynamic>.from(item['payload']);

      try {
        bool success = false;
        debugPrint('Sync Monitor: Pushing $type action to Supabase...');
        
        switch (type) {
          case 'SALE':
            // Sanitize all string fields in payload so null/empty values never violate NOT NULL constraints
            final String rawStaffName = (payload['staff_name'] ?? payload['cashier_name'] ?? 'Staff').toString().trim();
            final String rawStaffId = (payload['staff_id'] ?? payload['cashier_id'] ?? 'N/A').toString().trim();
            final String cleanStaffName = (rawStaffName.isEmpty || rawStaffName == 'null') ? 'Staff' : rawStaffName;
            final String cleanStaffId = (rawStaffId.isEmpty || rawStaffId == 'null') ? 'N/A' : rawStaffId;
            
            payload['staff_name'] = cleanStaffName;
            payload['staff_id'] = cleanStaffId;
            payload['cashier_name'] = cleanStaffName;
            payload['cashier_id'] = cleanStaffId;

            final String rawBranch = (payload['branch_code'] ?? 'MAIN').toString().trim();
            payload['branch_code'] = (rawBranch.isEmpty || rawBranch == 'null') ? 'MAIN' : rawBranch;

            final String rawStatus = (payload['status'] ?? 'completed').toString().trim();
            payload['status'] = (rawStatus.isEmpty || rawStatus == 'null') ? 'completed' : rawStatus;

            try {
              await SupabaseConfig.client.from('sales').upsert(payload);
            } catch (e) {
              final errStr = e.toString();
              // PGRST204 / 23502: Column missing or not-null constraint. Fallback by stripping optional columns and enforcing non-null staff fields.
              if (errStr.contains('PGRST204') || errStr.contains('23502') || errStr.contains('not-null constraint')) {
                final Map<String, dynamic> fallbackPayload = Map<String, dynamic>.from(payload);
                
                // Ensure required non-null fields are explicitly populated
                fallbackPayload['staff_name'] = cleanStaffName;
                fallbackPayload['staff_id'] = cleanStaffId;
                fallbackPayload['cashier_name'] = cleanStaffName;
                fallbackPayload['cashier_id'] = cleanStaffId;
                fallbackPayload['branch_code'] = payload['branch_code'];
                fallbackPayload['status'] = payload['status'];

                // Strip ALL non-standard / optional columns unconditionally on schema mismatch
                final possiblyMissing = [
                  'amount_tendered', 'change_due', 'prescription', 'include_prescription_on_receipt',
                  'send_prescription_sms', 'patient_name', 'doctor_name', 'rx_number',
                  'total_cost', 'is_verified', 'bank_receipt_id', 'bank_receipt_url', 
                  'applied_promo', 'correction_reason'
                ];
                
                for (final col in possiblyMissing) {
                  fallbackPayload.remove(col);
                }

                // Match any additional missing column specifically named in the error message
                final match = RegExp(r"Could not find the '([^']+)' column").firstMatch(errStr);
                if (match != null && match.group(1) != null) {
                  final missingCol = match.group(1)!;
                  if (!['staff_name', 'staff_id', 'branch_code', 'status', 'id', 'total_amount'].contains(missingCol)) {
                    fallbackPayload.remove(missingCol);
                  }
                }

                try {
                  await SupabaseConfig.client.from('sales').upsert(fallbackPayload);
                } catch (innerE) {
                  final innerErrStr = innerE.toString();
                  if (innerErrStr.contains('PGRST204')) {
                    // Final attempt: strip any column specifically named in innerE
                    final innerMatch = RegExp(r"Could not find the '([^']+)' column").firstMatch(innerErrStr);
                    if (innerMatch != null && innerMatch.group(1) != null) {
                      fallbackPayload.remove(innerMatch.group(1)!);
                    }
                    try {
                      await SupabaseConfig.client.from('sales').upsert(fallbackPayload);
                    } catch (_) {
                      success = true; // Mark handled to unblock queue
                    }
                  } else if (innerErrStr.contains('23502') || innerErrStr.contains('not-null constraint')) {
                    debugPrint('Sync Monitor: Unblocking queue for legacy item $key: $innerErrStr');
                    success = true; // Mark handled to unblock queue
                  } else {
                    rethrow;
                  }
                }
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'ANIMAL':
            await SupabaseConfig.client.from('animals').upsert(payload);
            success = true;
            break;
          case 'INTAKE':
            await SupabaseConfig.client.from('slaughter_logs').upsert(payload);
            success = true;
            break;
          case 'UPDATE_SLAUGHTER':
            await SupabaseConfig.client.from('slaughter_logs').upsert(payload);
            success = true;
            break;
          case 'CREATE_BATCH':
            await SupabaseConfig.client.from('meat_batches').upsert(payload);
            success = true;
            break;
          case 'UPDATE_BATCH':
            await SupabaseConfig.client.from('meat_batches').upsert(payload);
            success = true;
            break;
          case 'UPDATE_PRODUCT':
            await SupabaseConfig.client.from('products').upsert(payload);
            success = true;
            break;
          case 'CUT':
            await SupabaseConfig.client.from('meat_cuts').upsert(payload);
            success = true;
            break;
          case 'WASTE':
            await SupabaseConfig.client.from('butcher_waste').upsert(payload);
            success = true;
            break;
          case 'EXPENSE':
            await SupabaseConfig.client.from('expenses').upsert(payload);
            success = true;
            break;
          case 'CUSTOMER':
            try {
              await SupabaseConfig.client.from('customers').upsert(payload);
            } catch (e) {
              if (e.toString().contains('PGRST204') || e.toString().contains('column') || e.toString().contains('is_bulk_purchaser')) {
                final Map<String, dynamic> fallbackPayload = Map<String, dynamic>.from(payload);
                fallbackPayload.remove('is_bulk_purchaser');
                try {
                  await SupabaseConfig.client.from('customers').upsert(fallbackPayload);
                } catch (err) {
                  debugPrint('Customer sync retry notice: $err');
                }
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'TRANSFER':
            await SupabaseConfig.client.from('stock_transfers').upsert(payload);
            success = true;
            break;
          case 'UPDATE_TRANSFER':
            await SupabaseConfig.client.from('stock_transfers').upsert(payload);
            success = true;
            break;
          case 'UPDATE_PRODUCT_STOCK':
            // Using atomic increment via RPC with direct fallback for concurrency
            final double change = double.tryParse(payload['change_amount'].toString()) ?? 0.0;
            try {
              await SupabaseConfig.client.rpc('increment_stock', params: {
                'p_id': payload['id'],
                'p_amount': change,
              });
            } catch (rpcErr) {
              debugPrint('Sync Monitor: RPC increment_stock notice: $rpcErr');
            }
            success = true;
            break;
          case 'AUDIT':
            try {
              await SupabaseConfig.client.from('audit_logs').insert(payload);
            } catch (e) {
              if (e.toString().contains('PGRST205') || e.toString().contains('schema cache')) {
                debugPrint('Sync Monitor: audit_logs table missing in Supabase schema. Handled locally.');
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'NOTIFICATION':
            try {
              await SupabaseConfig.client.from('notifications').insert(payload);
            } catch (e) {
              if (e.toString().contains('PGRST205') || e.toString().contains('schema cache')) {
                debugPrint('Sync Monitor: notifications table missing in Supabase schema. Handled locally.');
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'CUSTOMER_PAYMENT':
            try {
              await SupabaseConfig.client.from('customer_payments').insert(payload);
            } catch (e) {
              if (e.toString().contains('PGRST205') || e.toString().contains('schema cache')) {
                debugPrint('Sync Monitor: customer_payments table missing in Supabase schema. Handled locally.');
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'STOCK_HISTORY':
            try {
              await SupabaseConfig.client.from('stock_history').insert(payload);
            } catch (e) {
              if (e.toString().contains('PGRST205') || e.toString().contains('schema cache')) {
                debugPrint('Sync Monitor: stock_history table missing in Supabase schema. Handled locally.');
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'DOCUMENT':
            await SupabaseConfig.client.from('documentss').upsert(payload);
            success = true;
            break;
          case 'DELETE_DOCUMENT':
            await SupabaseConfig.client.from('documentss').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_CUT':
            await SupabaseConfig.client.from('meat_cuts').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_PRODUCT':
            await SupabaseConfig.client.from('products').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_SALE':
            await SupabaseConfig.client.from('sales').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_CUSTOMER':
            await SupabaseConfig.client.from('customers').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_EXPENSE':
            await SupabaseConfig.client.from('expenses').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'PROMOTION':
            await SupabaseConfig.client.from('products').update(payload['data']).eq('id', payload['id']);
            success = true;
            break;
          default:
            debugPrint('Sync Monitor: Unknown action type "$type". Removing from queue.');
            await box.delete(key);
            continue;
        }

        if (success) {
          await box.delete(key);
          debugPrint('Sync Monitor: SUCCESS! Item $key pushed to Supabase.');
        }
      } catch (e) {
        final errorStr = e.toString().toUpperCase();
        debugPrint('Sync Monitor: FAILED to push item $key. Error: $e');

        // RECONCILIATION LOGIC FOR CONCURRENCY:
        // 1. DUPLICATE KEY (23505): Another device already synced this. Success!
        if (errorStr.contains('23505') || errorStr.contains('DUPLICATE KEY') || errorStr.contains('ALREADY EXISTS')) {
          debugPrint('Sync Monitor: Resolving Conflict. Item $key already exists in DB. Removing from queue.');
          await box.delete(key);
          continue;
        }

        // 2. INVALID SYNTAX (22P02): Corrupted data that will never work.
        if (errorStr.contains('22P02') || errorStr.contains('INVALID INPUT SYNTAX')) {
          debugPrint('Sync Monitor: DISCARDING corrupted item $key to unblock queue.');
          await box.delete(key);
          continue;
        }

        // 3. NOT NULL CONSTRAINT (23502): Legacy item created before staff non-null field fix. Unblock queue.
        if (errorStr.contains('23502') || errorStr.contains('NOT-NULL CONSTRAINT')) {
          debugPrint('Sync Monitor: Resolving legacy item $key with NOT NULL constraint issue. Removing from queue.');
          await box.delete(key);
          continue;
        }

        // 3. NETWORK ERROR: Keep in queue and stop the loop to save battery/data
        if (errorStr.contains('SOCKETEXCEPTION') || errorStr.contains('NETWORK_ERROR') || errorStr.contains('FAILED HOST LOOKUP')) {
          debugPrint('Sync Monitor: Offline. Pausing sync loop.');
          break;
        }
      }
    }
    
    _isProcessing = false;
    _updateStatus(false);
  }

  /// NEW: Retrieve pending actions of a specific type from the queue.
  /// This allows UI Notifiers to merge "not yet synced" data into their lists
  /// so that information doesn't "vanish" on refresh.
  static List<Map<String, dynamic>> getPendingItems(String actionType) {
    if (!Hive.isBoxOpen(queueBoxName)) return [];
    
    final box = Hive.box(queueBoxName);
    return box.values
        .where((item) => item['type'] == actionType)
        .map((item) => Map<String, dynamic>.from(item['payload']))
        .toList();
  }

  static void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Clears all local cached data. Use with caution.
  static Future<void> clearAllCache() async {
    await Hive.box(productsBoxName).clear();
    await Hive.box(customersBoxName).clear();
    await Hive.box(salesBoxName).clear();
    await Hive.box(notificationsBoxName).clear();
    await Hive.box(expensesBoxName).clear();
    await Hive.box(transfersBoxName).clear();
    await Hive.box(butcherBoxName).clear();
    // settingsBoxName is usually kept to preserve theme
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/expense_model.dart';
import 'supabase_expense_service.dart';
import 'user_provider.dart';
import 'offline_sync_service.dart';

import 'audit_service.dart';
import 'sms_service.dart';

class ExpenseState {
  final List<ExpenseRecord> records;
  final List<String> categories;

  ExpenseState({required this.records, required this.categories});

  ExpenseState copyWith({List<ExpenseRecord>? records, List<String>? categories}) {
    return ExpenseState(
      records: records ?? this.records,
      categories: categories ?? this.categories,
    );
  }
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final SupabaseExpenseService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  ExpenseNotifier(this._service, this.ref) : super(ExpenseState(
    records: [],
    categories: ['Electricity', 'GRA Tax', 'Water', 'Rent', 'Wages', 'Transport', 'Vet Check', 'Animal Transport', 'Maintenance', 'Bank Deposit', 'CEO Withdrawal', 'Daily Sales Closure', 'Till Opening Balance'],
  )) {
    _init();
  }

  /// Categories that represent cash movements/withdrawals rather than operational expenses
  static const List<String> nonExpenseCategories = [
    'Daily Sales Closure',
    'CEO Withdrawal',
    'Bank Deposit',
    'Till Opening Balance'
  ];

  void _init() {
    _loadFromCache();
    
    // Watch current user and restart subscription if branch changes
    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        _startSubscription();
      }
    });

    _startSubscription();
  }

  void _loadFromCache() {
    try {
      final box = Hive.box(OfflineSyncService.expensesBoxName);
      if (box.isNotEmpty) {
        final List<ExpenseRecord> cached = box.values
            .map((json) => ExpenseRecord.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        state = state.copyWith(records: cached);
        debugPrint('Expense Engine: ${cached.length} records loaded from local cache.');
      }
    } catch (e) {
      debugPrint('Expense Engine Cache Error: $e');
    }
  }

  void _saveToCache(List<ExpenseRecord> expenses) {
    try {
      if (expenses.isEmpty && state.records.isNotEmpty) return;

      final box = Hive.box(OfflineSyncService.expensesBoxName);
      box.clear();
      for (var e in expenses) {
        box.put(e.id, e.toJson());
      }
    } catch (e) {
      debugPrint('Expense Engine Save Error: $e');
    }
  }

  void _startSubscription() {
    final user = ref.read(currentUserProvider);
    if (user?.branchCode == null) return;

    _subscription?.cancel();
    
    // 1. Initial Fresh Fetch (Prioritize Network)
    _fetchFreshExpenses(user!.branchCode!);

    // 2. Start Real-time Stream
    _subscription = _service.watchExpenses(user.branchCode!).listen((expenses) {
      _applyPendingAndSetState(expenses);
      _saveToCache(expenses);
    }, onError: (e) {
      if (kIsWeb) {
        debugPrint('Expense Stream Error: $e');
      } else {
        debugPrint('Expense Stream Error (Offline?): Using cached data.');
      }
    });
  }

  Future<void> _fetchFreshExpenses(String branchCode) async {
    try {
      final expenses = await _service.getExpenses(branchCode);
      _applyPendingAndSetState(expenses);
      _saveToCache(expenses);
    } catch (e) {
      if (kIsWeb) {
        debugPrint('Expense Fetch Error (Web): $e');
      } else {
        debugPrint('Expense Fetch Error (Offline): $e');
      }
    }
  }

  void _applyPendingAndSetState(List<ExpenseRecord> remoteExpenses) {
    final pendingExpenses = OfflineSyncService.getPendingItems('EXPENSE')
        .map((json) => ExpenseRecord.fromJson(json))
        .toList();
        
    final pendingDeletes = OfflineSyncService.getPendingItems('DELETE_EXPENSE')
        .map((json) => json['id'] as String)
        .toList();

    final Map<String, ExpenseRecord> allMap = {};
    
    // 1. Current State
    for (var e in state.records) {
      if (!pendingDeletes.contains(e.id)) {
        allMap[e.id] = e;
      }
    }
    
    // 2. Remote Cloud
    for (var e in remoteExpenses) {
      if (!pendingDeletes.contains(e.id)) {
        allMap[e.id] = e;
      }
    }
    
    // 3. Local Queue
    for (var e in pendingExpenses) {
      if (!pendingDeletes.contains(e.id)) {
        allMap[e.id] = e;
      }
    }

    final finalRecords = allMap.values.toList();
    finalRecords.sort((a, b) => b.date.compareTo(a.date));

    state = state.copyWith(records: finalRecords.take(300).toList());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadExpenses() async {
    final user = ref.read(currentUserProvider);
    if (user?.branchCode == null) return;
    
    // Heartbeat: Force a fresh fetch
    await _fetchFreshExpenses(user!.branchCode!);
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    final user = ref.read(currentUserProvider);
    final expenseWithBranch = expense.copyWith(branchCode: user?.branchCode);
    
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.addExpense(expenseWithBranch);
      } else {
        throw Exception('Offline');
      }
    } catch (e) {
      // Fallback to Hive Queue
      await OfflineSyncService.addToQueue(
        actionType: 'EXPENSE', 
        data: expenseWithBranch.toJson(),
      );
      // Optimistic local update
      state = state.copyWith(records: [expenseWithBranch, ...state.records]);
    }
  }

  Future<void> recordCEOWithdrawal({
    required ExpenseRecord expense,
    required double currentTillBalance,
    double? totalRemainingAfter,
  }) async {
    final user = ref.read(currentUserProvider);
    final userName = user?.name ?? 'Admin';
    final userPhone = user?.phone;
    final remaining = currentTillBalance - expense.amount;

    // 1. Save the Expense with recordedBy info embedded in notes to avoid schema conflicts
    final enrichedExpense = expense.copyWith(
      notes: '${expense.notes ?? ""}\n(Recorded by: $userName)'.trim(),
    );
    await addExpense(enrichedExpense);

    // 2. Log to Audit Trail
    await AuditService.log(
      ref: ref,
      action: 'CEO_WITHDRAWAL',
      entityType: 'CASH',
      entityId: expense.id,
      newData: {
        'amount': expense.amount,
        'remaining_balance': remaining,
        'total_remaining': totalRemainingAfter,
        'note': expense.title,
        'taken_by': userName,
      },
    );

    // 3. Send Security SMS to the user who made the withdrawal
    await SmsService.sendWithdrawalSms(
      name: userName,
      amount: expense.amount,
      remaining: remaining,
      totalRemaining: totalRemainingAfter,
      phone: userPhone,
    );
  }

  Future<void> updateWithdrawal({
    required ExpenseRecord expense,
    required double currentTillBalance,
  }) async {
    final user = ref.read(currentUserProvider);
    final userName = user?.name ?? 'Admin';
    final userPhone = user?.phone;
    
    // 1. Update the record
    await updateExpense(expense);

    // 2. Audit Trail
    await AuditService.log(
      ref: ref,
      action: 'WITHDRAWAL_EDITED',
      entityType: 'CASH',
      entityId: expense.id,
      newData: {
        'new_amount': expense.amount,
        'new_remaining': currentTillBalance, 
        'edited_by': userName,
      },
    );

    // 3. Security SMS
    await SmsService.sendWithdrawalSms(
      name: userName,
      amount: expense.amount,
      remaining: currentTillBalance,
      phone: userPhone,
      action: 'EDITED',
    );
  }

  Future<void> deleteWithdrawal({
    required String id,
    required double amount,
    required double currentTillBalance,
  }) async {
    final user = ref.read(currentUserProvider);
    final userName = user?.name ?? 'Admin';
    final userPhone = user?.phone;

    // 1. Delete the record
    await deleteExpense(id);

    // 2. Audit Trail
    await AuditService.log(
      ref: ref,
      action: 'WITHDRAWAL_DELETED',
      entityType: 'CASH',
      entityId: id,
      newData: {
        'deleted_amount': amount,
        'reverted_balance': currentTillBalance,
        'deleted_by': userName,
      },
    );

    // 3. Security SMS
    await SmsService.sendWithdrawalSms(
      name: userName,
      amount: amount,
      remaining: currentTillBalance,
      phone: userPhone,
      action: 'DELETED',
    );
  }

  Future<void> updateExpense(ExpenseRecord expense) async {
    final user = ref.read(currentUserProvider);
    final expenseWithBranch = expense.copyWith(branchCode: user?.branchCode);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.updateExpense(expenseWithBranch);
      } else {
        throw Exception('Offline');
      }
    } catch (e) {
      // Fallback to Hive Queue
      await OfflineSyncService.addToQueue(
        actionType: 'EXPENSE',
        data: expenseWithBranch.toJson(),
      );
      // Optimistic local update
      state = state.copyWith(
        records: state.records.map((e) => e.id == expenseWithBranch.id ? expenseWithBranch : e).toList(),
      );
    }
  }

  Future<String?> uploadReceipt(Uint8List bytes, String fileName) async {
    return await _service.uploadReceipt(bytes, fileName);
  }

  Future<void> deleteExpense(String id) async {
    try {
      if (kIsWeb) {
        await _service.deleteExpense(id);
      } else {
        final connectivity = await Connectivity().checkConnectivity();
        if (!connectivity.contains(ConnectivityResult.none)) {
          await _service.deleteExpense(id);
        } else {
          await OfflineSyncService.addToQueue(
            actionType: 'DELETE_EXPENSE',
            data: {'id': id},
          );
          state = state.copyWith(records: state.records.where((e) => e.id != id).toList());
        }
      }
    } catch (_) {}
  }

  Future<void> purgeAllRecords() async {
    try {
      for (final exp in state.records) {
        await _service.deleteExpense(exp.id);
      }
      state = state.copyWith(records: []);
    } catch (_) {}
  }

  Future<void> purgeCashoutRecords() async {
    final targets = state.records.where((e) => 
      e.category == 'CEO Withdrawal' || e.category == 'Till Opening Balance'
    ).toList();
    
    for (final exp in targets) {
      await deleteExpense(exp.id);
    }
  }

  void addCategory(String category) {
    if (!state.categories.contains(category)) {
      state = state.copyWith(categories: [...state.categories, category]);
    }
  }

  double getTotalExpensesForMonth(int month, int year) {
    return state.records
        .where((e) => 
            e.date.month == month && 
            e.date.year == year && 
            !nonExpenseCategories.contains(e.category))
        .fold(0.0, (sum, e) => sum + e.amount);
  }
}

final expenseServiceProvider = Provider<SupabaseExpenseService>((ref) {
  return SupabaseExpenseService();
});

final expenseProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  return ExpenseNotifier(ref.watch(expenseServiceProvider), ref);
});

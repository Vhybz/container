import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import 'supabase_base_service.dart';

class SupabaseExpenseService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => ['receipt_url', 'notes', 'branch_code'];

  Future<List<ExpenseRecord>> getExpenses(String branchCode) async {
    final response = await selectSorted('expenses', order: 'date', filters: {'branch_code': branchCode});
    return response.map((json) => ExpenseRecord.fromJson(json)).toList();
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    await robustOperation('expenses', expense.toJson());
  }

  Future<void> updateExpense(ExpenseRecord expense) async {
    await robustOperation('expenses', expense.toJson(), isUpdate: true, updateId: expense.id);
  }

  Future<void> deleteExpense(String id) async {
    await client.from('expenses').delete().eq('id', id);
  }

  Stream<List<ExpenseRecord>> watchExpenses(String branchCode) {
    return watchTable('expenses', filters: {'branch_code': branchCode}, order: 'date')
        .map((data) => data.map((json) => ExpenseRecord.fromJson(json)).toList());
  }

  Future<String?> uploadReceipt(Uint8List bytes, String fileName) async {
    try {
      final storage = client.storage.from('receipts');
      await storage.uploadBinary(
        fileName, 
        bytes,
        fileOptions: const FileOptions(cacheControl: '31536000', upsert: true),
      );
      return storage.getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }
}

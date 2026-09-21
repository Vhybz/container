import '../models/sale_model.dart';
import 'supabase_base_service.dart';

class SupabaseSaleService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => [
    'cashier_id', 'cashier_name', 'staff_id', 'staff_name', 
    'total_cost', 'is_verified', 'bank_receipt_id', 'bank_receipt_url',
    'prescription', 'include_prescription_on_receipt', 'send_prescription_sms',
    'patient_name', 'doctor_name', 'rx_number'
  ];

  Future<List<SaleRecord>> getSales(String? branchCode, {bool canSeeAll = false}) async {
    final Map<String, dynamic> filters = {};
    if (!canSeeAll || (branchCode != null && branchCode != 'ALL' && branchCode.isNotEmpty)) {
       filters['branch_code'] = branchCode ?? 'MAIN';
    }

    final response = await selectSorted('sales', order: 'timestamp', filters: filters);
    return response.map((json) => SaleRecord.fromJson(json)).toList();
  }

  Future<void> saveSale(SaleRecord sale) async {
    await robustOperation('sales', sale.toJson());
  }

  Future<void> updateSale(SaleRecord sale) async {
    await robustOperation('sales', sale.toJson(), isUpdate: true, updateId: sale.id);
  }

  Future<void> deleteSales(List<String> ids) async {
    if (ids.isEmpty) return;
    await client.from('sales').delete().filter('id', 'in', '(${ids.join(',')})');
  }

  Stream<List<SaleRecord>> getSalesStream(String? branchCode, {bool canSeeAll = false}) {
    final Map<String, dynamic> filters = {};
    if (!canSeeAll || (branchCode != null && branchCode != 'ALL' && branchCode.isNotEmpty)) {
      filters['branch_code'] = branchCode ?? 'MAIN';
    }

    return watchTable('sales', filters: filters, order: 'timestamp')
        .map((data) => data.map((json) => SaleRecord.fromJson(json)).toList());
  }
}

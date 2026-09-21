import '../models/customer_model.dart';
import 'supabase_base_service.dart';

class SupabaseCustomerService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => [
    'is_bulk_purchaser', 'loyalty_points', 'visit_count', 'is_favorite'
  ];

  Future<List<Customer>> getCustomers(String branchCode) async {
    final Map<String, dynamic> filters = {};
    if (branchCode.isNotEmpty) {
      filters['branch_code'] = branchCode;
    }
    
    final response = await selectSorted('customers', order: 'name', ascending: true, filters: filters);
    return response.map((json) => Customer.fromJson(json)).toList();
  }

  Future<void> addCustomer(Customer customer) async {
    final Map<String, dynamic> data = customer.toJson();
    if (customer.id.startsWith('00000000')) {
      data.remove('id');
    }
    if (data['branch_code']?.toString().isEmpty ?? true) {
      data.remove('branch_code');
    }
    await robustOperation('customers', data);
  }

  Future<void> updateCustomer(Customer customer) async {
    await robustOperation('customers', customer.toJson(), isUpdate: true, updateId: customer.id);
  }

  Future<void> deleteCustomer(String id) async {
    await client.from('customers').delete().eq('id', id);
  }

  Stream<List<Customer>> watchCustomers(String branchCode) {
    final Map<String, dynamic> filters = {};
    if (branchCode.isNotEmpty) {
      filters['branch_code'] = branchCode;
    }

    return watchTable('customers', filters: filters, order: 'name')
        .map((data) => data.map((json) => Customer.fromJson(json)).where((c) => !c.isDeleted).toList());
  }
}

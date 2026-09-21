import '../models/transfer_models.dart';
import 'supabase_base_service.dart';

class SupabaseTransferService extends SupabaseBaseService {
  @override
  List<String> get riskyColumns => ['branch_code', 'unit'];

  Future<List<StockTransfer>> getTransfers() async {
    final response = await selectSorted('stock_transfers', order: 'transfer_time');
    return response.map((json) => StockTransfer.fromJson(json)).toList();
  }

  Future<void> addTransfer(StockTransfer transfer) async {
    await robustOperation('stock_transfers', transfer.toJson());
  }

  Future<void> updateTransferStatus(String id, TransferStatus status) async {
    await client.from('stock_transfers').update({'status': status.name}).eq('id', id);
  }

  Stream<List<StockTransfer>> watchTransfers() {
    return watchTable('stock_transfers', order: 'transfer_time')
        .map((data) => data.map((json) => StockTransfer.fromJson(json)).toList());
  }
}

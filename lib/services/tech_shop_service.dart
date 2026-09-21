import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tech_shop_models.dart';

class IMEINotifier extends StateNotifier<List<IMEIRecord>> {
  IMEINotifier() : super([]);

  void registerIMEI(IMEIRecord record) {
    state = [...state, record];
  }

  void updateIMEIStatus(String imei, String status) {
    state = state.map((r) {
      if (r.imei == imei) {
        return IMEIRecord(
          imei: r.imei,
          deviceModel: r.deviceModel,
          status: status,
          saleDate: status == 'Sold' ? DateTime.now() : r.saleDate,
          warrantyDurationMonths: r.warrantyDurationMonths,
        );
      }
      return r;
    }).toList();
  }
}

final imeiInventoryProvider = StateNotifierProvider<IMEINotifier, List<IMEIRecord>>((ref) {
  return IMEINotifier();
});

class RepairWorkOrderNotifier extends StateNotifier<List<RepairWorkOrder>> {
  RepairWorkOrderNotifier() : super([]);

  void createWorkOrder(RepairWorkOrder ticket) {
    state = [ticket, ...state];
  }

  void updateStatus(String ticketId, String status) {
    state = state.map((w) {
      if (w.ticketId == ticketId) {
        return RepairWorkOrder(
          ticketId: w.ticketId,
          customerName: w.customerName,
          customerPhone: w.customerPhone,
          deviceModel: w.deviceModel,
          issueDescription: w.issueDescription,
          laborCost: w.laborCost,
          partsCost: w.partsCost,
          status: status,
          createdAt: w.createdAt,
        );
      }
      return w;
    }).toList();
  }
}

final repairWorkOrdersProvider = StateNotifierProvider<RepairWorkOrderNotifier, List<RepairWorkOrder>>((ref) {
  return RepairWorkOrderNotifier();
});

class WarrantyNotifier extends StateNotifier<List<WarrantyCertificate>> {
  WarrantyNotifier() : super([]);

  void issueWarranty(WarrantyCertificate cert) {
    state = [cert, ...state];
  }
}

final warrantiesProvider = StateNotifierProvider<WarrantyNotifier, List<WarrantyCertificate>>((ref) {
  return WarrantyNotifier();
});

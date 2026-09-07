import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tech_shop_models.dart';

class IMEINotifier extends StateNotifier<List<IMEIRecord>> {
  IMEINotifier() : super([
    IMEIRecord(imei: '354892109283120', deviceModel: 'iPhone 15 Pro 128GB', status: 'In Stock', warrantyDurationMonths: 12),
    IMEIRecord(imei: '869201948210394', deviceModel: 'Samsung Galaxy S24 Ultra', status: 'In Stock', warrantyDurationMonths: 12),
    IMEIRecord(imei: '352910482019481', deviceModel: 'Google Pixel 8 Pro', status: 'In Stock', warrantyDurationMonths: 6),
  ]);

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
  RepairWorkOrderNotifier() : super([
    RepairWorkOrder(
      ticketId: 'REP-1021',
      customerName: 'Emmanuel Ofori',
      customerPhone: '0244123456',
      deviceModel: 'iPhone 13',
      issueDescription: 'Screen Replacement & Battery',
      laborCost: 400.0,
      partsCost: 800.0,
      status: 'In Progress',
    ),
  ]);

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
  WarrantyNotifier() : super([
    WarrantyCertificate(
      certificateId: 'WAR-8812',
      customerName: 'Emmanuel Ofori',
      deviceModel: 'iPhone 15 Pro',
      imei: '354892109283120',
      issueDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
    ),
  ]);

  void issueWarranty(WarrantyCertificate cert) {
    state = [cert, ...state];
  }
}

final warrantiesProvider = StateNotifierProvider<WarrantyNotifier, List<WarrantyCertificate>>((ref) {
  return WarrantyNotifier();
});

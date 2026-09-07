import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_models.dart';

class PharmacyService extends StateNotifier<List<MedicationBatch>> {
  PharmacyService() : super([
    MedicationBatch(
      id: 'B1',
      drugName: 'Amoxicillin 500mg Capsules',
      batchNumber: 'BAT-2024-001',
      expiryDate: DateTime.now().add(const Duration(days: 400)),
      stockQuantity: 45,
      costPrice: 15.0,
      sellingPrice: 25.0,
      supplier: 'PharmaGlow Ltd',
    ),
    MedicationBatch(
      id: 'B2',
      drugName: 'Paracetamol Extra 500mg',
      batchNumber: 'BAT-2024-088',
      expiryDate: DateTime.now().add(const Duration(days: 15)), // Expiring soon
      stockQuantity: 12,
      costPrice: 5.0,
      sellingPrice: 10.0,
      supplier: 'KofiPharma Ghana',
    ),
    MedicationBatch(
      id: 'B3',
      drugName: 'Metformin 850mg',
      batchNumber: 'BAT-2023-412',
      expiryDate: DateTime.now().subtract(const Duration(days: 5)), // Expired
      stockQuantity: 8,
      costPrice: 20.0,
      sellingPrice: 35.0,
      supplier: 'MedLab Corp',
    ),
  ]);

  void addBatch(MedicationBatch batch) {
    state = [...state, batch];
  }

  void updateStock(String batchNumber, int deltaQuantity) {
    state = state.map((b) {
      if (b.batchNumber == batchNumber) {
        return MedicationBatch(
          id: b.id,
          drugName: b.drugName,
          batchNumber: b.batchNumber,
          expiryDate: b.expiryDate,
          stockQuantity: (b.stockQuantity + deltaQuantity).clamp(0, 999999),
          costPrice: b.costPrice,
          sellingPrice: b.sellingPrice,
          supplier: b.supplier,
        );
      }
      return b;
    }).toList();
  }
}

final pharmacyBatchesProvider = StateNotifierProvider<PharmacyService, List<MedicationBatch>>((ref) {
  return PharmacyService();
});

class PrescriptionNotifier extends StateNotifier<List<PrescriptionRecord>> {
  PrescriptionNotifier() : super([
    PrescriptionRecord(
      id: 'RX-8821',
      rxNumber: 'RX-8821',
      patientName: 'Kwame Mensah',
      doctorName: 'Dr. A. Osei',
      medications: ['Amoxicillin 500mg (x21)', 'Paracetamol Extra (x10)'],
      dispensedAt: DateTime.now(),
      status: 'Dispensed',
    ),
  ]);

  void recordPrescription(PrescriptionRecord record) {
    state = [record, ...state];
  }
}

final prescriptionsProvider = StateNotifierProvider<PrescriptionNotifier, List<PrescriptionRecord>>((ref) {
  return PrescriptionNotifier();
});

final drugExpiryAlertsProvider = Provider<List<DrugExpiryAlert>>((ref) {
  final batches = ref.watch(pharmacyBatchesProvider);
  return batches
      .where((b) => b.isExpired || b.isExpiringSoon)
      .map((b) => DrugExpiryAlert(
            id: b.id,
            drugName: b.drugName,
            batchNumber: b.batchNumber,
            expiryDate: b.expiryDate,
            stockRemaining: b.stockQuantity,
            severity: b.isExpired ? 'Critical' : 'High',
          ))
      .toList();
});

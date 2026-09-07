class MedicationBatch {
  final String id;
  final String drugName;
  final String batchNumber;
  final DateTime expiryDate;
  final int stockQuantity;
  final double costPrice;
  final double sellingPrice;
  final String? supplier;

  MedicationBatch({
    required this.id,
    required this.drugName,
    required this.batchNumber,
    required this.expiryDate,
    required this.stockQuantity,
    required this.costPrice,
    required this.sellingPrice,
    this.supplier,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isExpiringSoon {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return !isExpired && daysUntilExpiry <= 60;
  }

  factory MedicationBatch.fromJson(Map<String, dynamic> json) {
    return MedicationBatch(
      id: json['id'] ?? '',
      drugName: json['drug_name'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      expiryDate: DateTime.tryParse(json['expiry_date'] ?? '') ?? DateTime.now(),
      stockQuantity: (json['stock_quantity'] as num? ?? 0).toInt(),
      costPrice: (json['cost_price'] as num? ?? 0.0).toDouble(),
      sellingPrice: (json['selling_price'] as num? ?? 0.0).toDouble(),
      supplier: json['supplier'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'drug_name': drugName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'stock_quantity': stockQuantity,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'supplier': supplier,
    };
  }
}

class PrescriptionRecord {
  final String id;
  final String rxNumber;
  final String patientName;
  final String? doctorName;
  final List<String> medications;
  final DateTime dispensedAt;
  final String status; // 'Dispensed', 'Pending', 'Cancelled'

  PrescriptionRecord({
    required this.id,
    required this.rxNumber,
    required this.patientName,
    this.doctorName,
    required this.medications,
    DateTime? dispensedAt,
    this.status = 'Dispensed',
  }) : dispensedAt = dispensedAt ?? DateTime.now();

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    return PrescriptionRecord(
      id: json['id'] ?? '',
      rxNumber: json['rx_number'] ?? '',
      patientName: json['patient_name'] ?? '',
      doctorName: json['doctor_name'],
      medications: List<String>.from(json['medications'] ?? []),
      dispensedAt: DateTime.tryParse(json['dispensed_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'Dispensed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rx_number': rxNumber,
      'patient_name': patientName,
      'doctor_name': doctorName,
      'medications': medications,
      'dispensed_at': dispensedAt.toIso8601String(),
      'status': status,
    };
  }
}

class DrugExpiryAlert {
  final String id;
  final String drugName;
  final String batchNumber;
  final DateTime expiryDate;
  final int stockRemaining;
  final String severity; // 'High', 'Medium', 'Critical'

  DrugExpiryAlert({
    required this.id,
    required this.drugName,
    required this.batchNumber,
    required this.expiryDate,
    required this.stockRemaining,
    required this.severity,
  });

  factory DrugExpiryAlert.fromJson(Map<String, dynamic> json) {
    return DrugExpiryAlert(
      id: json['id'] ?? '',
      drugName: json['drug_name'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      expiryDate: DateTime.tryParse(json['expiry_date'] ?? '') ?? DateTime.now(),
      stockRemaining: (json['stock_remaining'] as num? ?? 0).toInt(),
      severity: json['severity'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'drug_name': drugName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String(),
      'stock_remaining': stockRemaining,
      'severity': severity,
    };
  }
}

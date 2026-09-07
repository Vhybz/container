class IMEIRecord {
  final String imei;
  final String deviceModel;
  final String status; // 'In Stock', 'Sold', 'Under Repair'
  final DateTime? saleDate;
  final int warrantyDurationMonths;

  IMEIRecord({
    required this.imei,
    required this.deviceModel,
    this.status = 'In Stock',
    this.saleDate,
    this.warrantyDurationMonths = 12,
  });

  factory IMEIRecord.fromJson(Map<String, dynamic> json) {
    return IMEIRecord(
      imei: json['imei'] ?? '',
      deviceModel: json['device_model'] ?? '',
      status: json['status'] ?? 'In Stock',
      saleDate: json['sale_date'] != null ? DateTime.tryParse(json['sale_date']) : null,
      warrantyDurationMonths: (json['warranty_duration_months'] as num? ?? 12).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imei': imei,
      'device_model': deviceModel,
      'status': status,
      'sale_date': saleDate?.toIso8601String(),
      'warranty_duration_months': warrantyDurationMonths,
    };
  }
}

class RepairWorkOrder {
  final String ticketId;
  final String customerName;
  final String? customerPhone;
  final String deviceModel;
  final String issueDescription;
  final double laborCost;
  final double partsCost;
  final String status; // 'Pending Parts', 'In Progress', 'Ready for Pickup', 'Completed'
  final DateTime createdAt;

  RepairWorkOrder({
    required this.ticketId,
    required this.customerName,
    this.customerPhone,
    required this.deviceModel,
    required this.issueDescription,
    required this.laborCost,
    required this.partsCost,
    this.status = 'In Progress',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalCost => laborCost + partsCost;

  factory RepairWorkOrder.fromJson(Map<String, dynamic> json) {
    return RepairWorkOrder(
      ticketId: json['ticket_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'],
      deviceModel: json['device_model'] ?? '',
      issueDescription: json['issue_description'] ?? '',
      laborCost: (json['labor_cost'] as num? ?? 0.0).toDouble(),
      partsCost: (json['parts_cost'] as num? ?? 0.0).toDouble(),
      status: json['status'] ?? 'In Progress',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_id': ticketId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'device_model': deviceModel,
      'issue_description': issueDescription,
      'labor_cost': laborCost,
      'parts_cost': partsCost,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class WarrantyCertificate {
  final String certificateId;
  final String customerName;
  final String deviceModel;
  final String imei;
  final DateTime issueDate;
  final DateTime expiryDate;
  final String terms;

  WarrantyCertificate({
    required this.certificateId,
    required this.customerName,
    required this.deviceModel,
    required this.imei,
    required this.issueDate,
    required this.expiryDate,
    this.terms = 'Standard 12-Month Hardware Warranty (Excludes water damage & screen cracks)',
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  factory WarrantyCertificate.fromJson(Map<String, dynamic> json) {
    return WarrantyCertificate(
      certificateId: json['certificate_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      deviceModel: json['device_model'] ?? '',
      imei: json['imei'] ?? '',
      issueDate: DateTime.tryParse(json['issue_date'] ?? '') ?? DateTime.now(),
      expiryDate: DateTime.tryParse(json['expiry_date'] ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      terms: json['terms'] ?? 'Standard Hardware Warranty',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificate_id': certificateId,
      'customer_name': customerName,
      'device_model': deviceModel,
      'imei': imei,
      'issue_date': issueDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'terms': terms,
    };
  }
}

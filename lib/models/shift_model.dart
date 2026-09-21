class ShiftRecord {
  final String id;
  final String branchCode;
  final String cashierId;
  final String cashierName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // 'open', 'closed'
  final double openingFloat;
  final double expectedCashSales;
  final double? actualCashCounted;
  final double? cashVariance; // actualCashCounted - (openingFloat + expectedCashSales)
  final double momoSales;
  final double cardSales;
  final double totalSales;
  final String? notes;
  final DateTime createdAt;

  ShiftRecord({
    required this.id,
    required this.branchCode,
    required this.cashierId,
    required this.cashierName,
    required this.startTime,
    this.endTime,
    this.status = 'open',
    required this.openingFloat,
    this.expectedCashSales = 0.0,
    this.actualCashCounted,
    this.cashVariance,
    this.momoSales = 0.0,
    this.cardSales = 0.0,
    this.totalSales = 0.0,
    this.notes,
    required this.createdAt,
  });

  factory ShiftRecord.fromJson(Map<String, dynamic> json) {
    return ShiftRecord(
      id: json['id'] as String,
      branchCode: json['branch_code'] as String? ?? 'MAIN',
      cashierId: json['cashier_id'] as String? ?? 'N/A',
      cashierName: json['cashier_name'] as String? ?? 'Cashier',
      startTime: json['start_time'] != null ? DateTime.parse(json['start_time']) : DateTime.now(),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'] as String? ?? 'open',
      openingFloat: (json['opening_float'] as num? ?? 0.0).toDouble(),
      expectedCashSales: (json['expected_cash_sales'] as num? ?? 0.0).toDouble(),
      actualCashCounted: (json['actual_cash_counted'] as num?)?.toDouble(),
      cashVariance: (json['cash_variance'] as num?)?.toDouble(),
      momoSales: (json['momo_sales'] as num? ?? 0.0).toDouble(),
      cardSales: (json['card_sales'] as num? ?? 0.0).toDouble(),
      totalSales: (json['total_sales'] as num? ?? 0.0).toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'branch_code': branchCode,
    'cashier_id': cashierId,
    'cashier_name': cashierName,
    'start_time': startTime.toIso8601String(),
    if (endTime != null) 'end_time': endTime!.toIso8601String(),
    'status': status,
    'opening_float': openingFloat,
    'expected_cash_sales': expectedCashSales,
    if (actualCashCounted != null) 'actual_cash_counted': actualCashCounted,
    if (cashVariance != null) 'cash_variance': cashVariance,
    'momo_sales': momoSales,
    'card_sales': cardSales,
    'total_sales': totalSales,
    if (notes != null) 'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  ShiftRecord copyWith({
    String? id,
    String? branchCode,
    String? cashierId,
    String? cashierName,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? openingFloat,
    double? expectedCashSales,
    double? actualCashCounted,
    double? cashVariance,
    double? momoSales,
    double? cardSales,
    double? totalSales,
    String? notes,
    DateTime? createdAt,
  }) {
    return ShiftRecord(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      openingFloat: openingFloat ?? this.openingFloat,
      expectedCashSales: expectedCashSales ?? this.expectedCashSales,
      actualCashCounted: actualCashCounted ?? this.actualCashCounted,
      cashVariance: cashVariance ?? this.cashVariance,
      momoSales: momoSales ?? this.momoSales,
      cardSales: cardSales ?? this.cardSales,
      totalSales: totalSales ?? this.totalSales,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

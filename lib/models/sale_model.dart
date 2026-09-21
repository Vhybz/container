import 'product.dart';

enum PaymentMethod { cash, mobileMoney, bankDeposit }

enum SaleStatus { completed, pendingCorrection, rectified, cancelled, awaitingDeposit, reversed }

class PaymentDetail {
  final PaymentMethod method;
  final double amount;
  final String? reference; // For mobile/card refs
  final bool isPaystack;
  final DateTime? date;

  PaymentDetail({
    required this.method,
    required this.amount,
    this.reference,
    this.isPaystack = false,
    this.date,
  });

  factory PaymentDetail.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json);
    return PaymentDetail(
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == map['method'],
        orElse: () => PaymentMethod.cash,
      ),
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      reference: map['reference'],
      isPaystack: map['is_paystack'] ?? false,
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'method': method.name,
    'amount': amount,
    'reference': reference,
    'is_paystack': isPaystack,
    'date': date?.toIso8601String(),
  };
}

class SaleItem {
  final Product product;
  final double quantity;
  final double priceAtSale;
  final double originalPrice;

  SaleItem({
    required this.product,
    required this.quantity,
    required this.priceAtSale,
    required this.originalPrice,
  });

  factory SaleItem.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json);
    return SaleItem(
      product: Product.fromJson(map['product']),
      quantity: (map['quantity'] as num).toDouble(),
      priceAtSale: (map['price_at_sale'] as num).toDouble(),
      originalPrice: (map['original_price'] as num? ?? (map['price_at_sale'] as num)).toDouble(),
    );
  }

  double get total => quantity * priceAtSale;
  double get discount => (originalPrice - priceAtSale) * quantity;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'price_at_sale': priceAtSale,
    'original_price': originalPrice,
  };
}

class SaleRecord {
  final String id;
  final String? branchCode;
  final List<SaleItem> items;
  final double totalAmount; // This is the Net Invoice Value (After Discount)
  final double totalDiscount; // Total revenue loss from promotions
  final double totalCost; // Total cost for profit analytics
  final String? appliedPromo; // Description of applied promo
  final List<PaymentDetail> payments;
  final DateTime timestamp;
  final String cashierName;
  final String cashierId;
  final String? customerName;
  final String? customerPhone;
  final SaleStatus status;
  final String? correctionReason;
  final String? bankReceiptUrl;
  final String? bankReceiptId;
  final bool isVerified;
  final String? prescription; // Prescribed medication & dosage instructions
  final bool includePrescriptionOnReceipt; // Whether to print prescription on the receipt
  final bool sendPrescriptionSms; // Whether prescription was requested to be sent as SMS
  final String? patientName; // Optional patient name
  final String? doctorName; // Optional doctor / prescriber name
  final String? rxNumber; // Optional Rx Serial Number
  final double? amountTendered; // Physical cash amount handed by customer
  final double? changeDue; // Change calculated and given to customer

  SaleRecord({
    required this.id,
    this.branchCode,
    required this.items,
    required this.totalAmount,
    this.totalDiscount = 0.0,
    this.totalCost = 0.0,
    this.appliedPromo,
    required this.payments,
    required this.timestamp,
    required this.cashierName,
    required this.cashierId,
    this.customerName,
    this.customerPhone,
    this.status = SaleStatus.completed,
    this.correctionReason,
    this.bankReceiptUrl,
    this.bankReceiptId,
    this.isVerified = false,
    this.prescription,
    this.includePrescriptionOnReceipt = true,
    this.sendPrescriptionSms = false,
    this.patientName,
    this.doctorName,
    this.rxNumber,
    this.amountTendered,
    this.changeDue,
  });

  factory SaleRecord.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json);
    return SaleRecord(
      id: map['id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
      branchCode: map['branch_code'],
      items: (map['items'] as List?)?.map((e) => SaleItem.fromJson(e)).toList() ?? [],
      totalAmount: (map['total_amount'] as num? ?? 0.0).toDouble(),
      totalDiscount: (map['total_discount'] as num? ?? 0.0).toDouble(),
      totalCost: (map['total_cost'] as num? ?? 0.0).toDouble(),
      appliedPromo: map['applied_promo'],
      payments: (map['payments'] as List?)?.map((e) => PaymentDetail.fromJson(e)).toList() ?? [],
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      cashierName: (map['staff_name'] ?? map['cashier_name'] ?? 'System').toString(),
      cashierId: (map['staff_id'] ?? map['cashier_id'] ?? 'system').toString(),
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      status: SaleStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SaleStatus.completed,
      ),
      correctionReason: map['correction_reason'],
      bankReceiptUrl: map['bank_receipt_url'],
      bankReceiptId: map['bank_receipt_id'],
      isVerified: map['is_verified'] ?? false,
      prescription: map['prescription'],
      includePrescriptionOnReceipt: map['include_prescription_on_receipt'] ?? true,
      sendPrescriptionSms: map['send_prescription_sms'] ?? false,
      patientName: map['patient_name'],
      doctorName: map['doctor_name'],
      rxNumber: map['rx_number'],
      amountTendered: (map['amount_tendered'] as num?)?.toDouble(),
      changeDue: (map['change_due'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_code': branchCode,
      'items': items.map((e) => e.toJson()).toList(),
      'total_amount': totalAmount,
      'total_discount': totalDiscount,
      'total_cost': totalCost,
      'applied_promo': appliedPromo,
      'payments': payments.map((e) => e.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'cashier_name': cashierName,
      'cashier_id': cashierId,
      'staff_name': cashierName, // Mapping for older database schemas
      'staff_id': cashierId, // Mapping for older database schemas
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'status': status.name,
      'correction_reason': correctionReason,
      'bank_receipt_url': bankReceiptUrl,
      'bank_receipt_id': bankReceiptId,
      'is_verified': isVerified,
      'prescription': prescription,
      'include_prescription_on_receipt': includePrescriptionOnReceipt,
      'send_prescription_sms': sendPrescriptionSms,
      'patient_name': patientName,
      'doctor_name': doctorName,
      'rx_number': rxNumber,
      'amount_tendered': amountTendered,
      'change_due': changeDue,
    };
  }

  // Financial Breakdown Calculations
  double get totalQty => items.fold(0, (sum, item) => sum + item.quantity);
  int get productCount => items.length;
  
  // Base total before discounts
  double get baseTotal => totalAmount + totalDiscount;

  // Calculations based on the Ghanaian Tax system (Standard Rate)
  // Basic Amount (Exclusive of Levies and VAT)
  double get taxExclusiveAmount => totalAmount / 1.219; // Mathematical reverse of standard rate

  double get getFundAmount => taxExclusiveAmount * 0.025;
  double get nhilAmount => taxExclusiveAmount * 0.025;
  double get covidLevyAmount => taxExclusiveAmount * 0.01;
  
  // Taxable Value for VAT = Exclusive + Levies
  double get taxableValueForVat => taxExclusiveAmount + getFundAmount + nhilAmount + covidLevyAmount;
  
  double get vatAmount => taxableValueForVat * 0.15;

  // Verification: taxExclusiveAmount + getFund + nhil + covid + vat should approx totalAmount
  
  // Alternative: Flat Rate (3% + 1% COVID) = 4% total on top
  double get flatRateVatAmount => totalAmount * 0.03;
  double get flatRateCovidAmount => totalAmount * 0.01;

  double get netInvoiceValue => totalAmount;

  // Aliases for backward compatibility
  double get basicAmount => taxExclusiveAmount;
  double get getFund => getFundAmount;
  double get nhil => nhilAmount;
  double get vat => vatAmount;
  double get subTotal => totalAmount;

  double get amountPaid => payments.fold(0, (sum, p) => sum + p.amount);
  double get balance => totalAmount - amountPaid;
  double get effectiveChange => changeDue ?? (amountTendered != null && amountTendered! > totalAmount ? amountTendered! - totalAmount : 0.0);

  bool get isActive => status != SaleStatus.cancelled && status != SaleStatus.reversed;

  SaleRecord copyWith({
    String? branchCode,
    List<SaleItem>? items,
    double? totalAmount,
    double? totalDiscount,
    double? totalCost,
    String? appliedPromo,
    List<PaymentDetail>? payments,
    SaleStatus? status,
    String? correctionReason,
    String? bankReceiptUrl,
    String? bankReceiptId,
    bool? isVerified,
    String? customerName,
    String? customerPhone,
    String? prescription,
    bool? includePrescriptionOnReceipt,
    bool? sendPrescriptionSms,
    String? patientName,
    String? doctorName,
    String? rxNumber,
    double? amountTendered,
    double? changeDue,
  }) {
    return SaleRecord(
      id: id,
      branchCode: branchCode ?? this.branchCode,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      totalCost: totalCost ?? this.totalCost,
      appliedPromo: appliedPromo ?? this.appliedPromo,
      payments: payments ?? this.payments,
      timestamp: timestamp,
      cashierName: cashierName,
      cashierId: cashierId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      status: status ?? this.status,
      correctionReason: correctionReason ?? this.correctionReason,
      bankReceiptUrl: bankReceiptUrl ?? this.bankReceiptUrl,
      bankReceiptId: bankReceiptId ?? this.bankReceiptId,
      isVerified: isVerified ?? this.isVerified,
      prescription: prescription ?? this.prescription,
      includePrescriptionOnReceipt: includePrescriptionOnReceipt ?? this.includePrescriptionOnReceipt,
      sendPrescriptionSms: sendPrescriptionSms ?? this.sendPrescriptionSms,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      rxNumber: rxNumber ?? this.rxNumber,
      amountTendered: amountTendered ?? this.amountTendered,
      changeDue: changeDue ?? this.changeDue,
    );
  }
}

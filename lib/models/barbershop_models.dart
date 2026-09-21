import 'dart:convert';

class BarberService {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final double commissionAmount;

  BarberService({
    required this.id,
    required this.name,
    required this.price,
    this.durationMinutes = 30,
    double? commissionAmount,
    double? commissionPercentage,
  }) : commissionAmount = commissionAmount ??
            (commissionPercentage != null
                ? (price * commissionPercentage / 100.0)
                : 20.0);

  /// Backward compatible computed percentage
  double get commissionPercentage =>
      price > 0 ? ((commissionAmount / price) * 100.0) : 40.0;

  factory BarberService.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num? ?? 0.0).toDouble();
    final commAmount = (json['commission_amount'] as num?)?.toDouble() ??
        ((json['commission_percentage'] as num?) != null
            ? (price * (json['commission_percentage'] as num).toDouble() / 100.0)
            : 20.0);

    return BarberService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: price,
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      commissionAmount: commAmount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
      'commission_amount': commissionAmount,
      'commission_percentage': commissionPercentage,
    };
  }
}

class AppointmentQueue {
  final String id;
  final String customerName;
  final String serviceName;
  final String assignedBarberId;
  final String assignedBarberName;
  final String scheduledTime;
  final String status; // 'Waiting', 'In Service', 'Completed', 'Cancelled'

  AppointmentQueue({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.assignedBarberId,
    required this.assignedBarberName,
    required this.scheduledTime,
    this.status = 'Waiting',
  });

  factory AppointmentQueue.fromJson(Map<String, dynamic> json) {
    return AppointmentQueue(
      id: json['id'] ?? '',
      customerName: json['customer_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      assignedBarberId: json['assigned_barber_id'] ?? '',
      assignedBarberName: json['assigned_barber_name'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      status: json['status'] ?? 'Waiting',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_name': customerName,
      'service_name': serviceName,
      'assigned_barber_id': assignedBarberId,
      'assigned_barber_name': assignedBarberName,
      'scheduled_time': scheduledTime,
      'status': status,
    };
  }
}

class BarberCommissionLog {
  final String id;
  final String barberId;
  final String barberName;
  final String serviceName;
  final double saleAmount;
  final double commissionEarned;
  final double tipAmount;
  final DateTime date;

  BarberCommissionLog({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.serviceName,
    required this.saleAmount,
    required this.commissionEarned,
    this.tipAmount = 0.0,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  factory BarberCommissionLog.fromJson(Map<String, dynamic> json) {
    return BarberCommissionLog(
      id: json['id'] ?? '',
      barberId: json['barber_id'] ?? '',
      barberName: json['barber_name'] ?? '',
      serviceName: json['service_name'] ?? '',
      saleAmount: (json['sale_amount'] as num? ?? 0.0).toDouble(),
      commissionEarned: (json['commission_earned'] as num? ?? 0.0).toDouble(),
      tipAmount: (json['tip_amount'] as num? ?? 0.0).toDouble(),
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barber_id': barberId,
      'barber_name': barberName,
      'service_name': serviceName,
      'sale_amount': saleAmount,
      'commission_earned': commissionEarned,
      'tip_amount': tipAmount,
      'date': date.toIso8601String(),
    };
  }

  factory BarberCommissionLog.fromRecord(BarberRecord record) {
    return BarberCommissionLog(
      id: record.id,
      barberId: record.barber,
      barberName: record.barber,
      serviceName: record.service,
      saleAmount: record.price,
      commissionEarned: record.effectiveCommission,
      tipAmount: record.tip,
      date: record.timestamp,
    );
  }
}

class BarberAppointment {
  final String id;
  final String branchCode;
  final String? customerId;
  final String customerName;
  final String phone;
  final String service;
  final String barber;
  final DateTime appointmentTime;
  final int durationMinutes;
  final double price;
  final String status; // 'Pending Payment', 'Scheduled', 'Queued', 'In Service', 'Completed', 'Cancelled'
  final String paymentStatus; // 'Pending', 'Validated'
  final DateTime? validatedAt;
  final bool isQueued;
  final bool reminderSent;
  final String? notes;
  final String? bookedBy;
  final String? momoNumber;
  final String? momoName;
  final DateTime createdAt;

  static const String defaultMomoNumber = '0552857861';
  static const String defaultMomoName = 'Emmanuel ADU Adjei';

  String get effectiveMomoNumber => (momoNumber != null && momoNumber!.trim().isNotEmpty) ? momoNumber!.trim() : defaultMomoNumber;
  String get effectiveMomoName => (momoName != null && momoName!.trim().isNotEmpty) ? momoName!.trim() : defaultMomoName;

  BarberAppointment({
    required this.id,
    this.branchCode = 'MAIN',
    this.customerId,
    required this.customerName,
    required this.phone,
    required this.service,
    required this.barber,
    required this.appointmentTime,
    this.durationMinutes = 30,
    required this.price,
    this.status = 'Pending Payment',
    this.paymentStatus = 'Pending',
    this.validatedAt,
    this.isQueued = false,
    this.reminderSent = false,
    this.notes,
    this.bookedBy,
    this.momoNumber,
    this.momoName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPendingPayment => status == 'Pending Payment' || paymentStatus == 'Pending';

  bool get isDueForQueue {
    if (isPendingPayment || isQueued || status == 'Cancelled' || status == 'Completed') return false;
    final thirtyMinsPrior = appointmentTime.subtract(const Duration(minutes: 30));
    return DateTime.now().isAfter(thirtyMinsPrior);
  }

  factory BarberAppointment.fromJson(Map<String, dynamic> json) {
    final statusVal = json['status'] ?? 'Scheduled';
    return BarberAppointment(
      id: json['id'] ?? '',
      branchCode: json['branch_code'] ?? 'MAIN',
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? json['customer'] ?? '',
      phone: json['phone'] ?? '',
      service: json['service'] ?? '',
      barber: json['barber'] ?? '',
      appointmentTime: DateTime.tryParse(json['appointment_time'] ?? '') ?? DateTime.now(),
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      price: (json['price'] as num? ?? 0.0).toDouble(),
      status: statusVal,
      paymentStatus: json['payment_status'] ?? (statusVal == 'Pending Payment' ? 'Pending' : 'Validated'),
      validatedAt: json['validated_at'] != null ? DateTime.tryParse(json['validated_at']) : null,
      isQueued: json['is_queued'] == true,
      reminderSent: json['reminder_sent'] == true,
      notes: json['notes'],
      bookedBy: json['booked_by'],
      momoNumber: json['momo_number'] as String?,
      momoName: json['momo_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_code': branchCode,
      if (customerId != null) 'customer_id': customerId,
      'customer_name': customerName,
      'phone': phone,
      'service': service,
      'barber': barber,
      'appointment_time': appointmentTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'price': price,
      'status': status,
      'payment_status': paymentStatus,
      if (validatedAt != null) 'validated_at': validatedAt!.toIso8601String(),
      'is_queued': isQueued,
      'reminder_sent': reminderSent,
      if (notes != null) 'notes': notes,
      if (bookedBy != null) 'booked_by': bookedBy,
      if (momoNumber != null) 'momo_number': momoNumber,
      if (momoName != null) 'momo_name': momoName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BarberAppointment copyWith({
    String? id,
    String? branchCode,
    String? customerId,
    String? customerName,
    String? phone,
    String? service,
    String? barber,
    DateTime? appointmentTime,
    int? durationMinutes,
    double? price,
    String? status,
    String? paymentStatus,
    DateTime? validatedAt,
    bool? isQueued,
    bool? reminderSent,
    String? notes,
    String? bookedBy,
    String? momoNumber,
    String? momoName,
    DateTime? createdAt,
  }) {
    return BarberAppointment(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      service: service ?? this.service,
      barber: barber ?? this.barber,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      validatedAt: validatedAt ?? this.validatedAt,
      isQueued: isQueued ?? this.isQueued,
      reminderSent: reminderSent ?? this.reminderSent,
      notes: notes ?? this.notes,
      bookedBy: bookedBy ?? this.bookedBy,
      momoNumber: momoNumber ?? this.momoNumber,
      momoName: momoName ?? this.momoName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class BarberRecord {
  final String id;
  final String branchCode;
  final String customerName;
  final String customerPhone;
  final String service;
  final String serviceCategory;
  final String barber;
  final String attendant;
  final double price;
  final double tip;
  final double totalPaid;
  final String paymentMethod;
  final DateTime timestamp;
  final String? saleId;
  final String? queueId;
  final String? appointmentId;
  final String source;
  final String? notes;
  final double commissionRate;
  final double? commissionAmount;

  BarberRecord({
    required this.id,
    this.branchCode = 'MAIN',
    required this.customerName,
    this.customerPhone = '',
    required this.service,
    this.serviceCategory = 'Haircut',
    required this.barber,
    this.attendant = 'Staff',
    required this.price,
    this.tip = 0.0,
    double? totalPaid,
    this.paymentMethod = 'Cash',
    required this.timestamp,
    this.saleId,
    this.queueId,
    this.appointmentId,
    this.source = 'Queue',
    this.notes,
    this.commissionRate = 40.0,
    this.commissionAmount,
  }) : totalPaid = totalPaid ?? (price + tip);

  /// Exactly calculates commission earned on this haircut/grooming service
  double get effectiveCommission =>
      commissionAmount ?? ((price * commissionRate) / 100.0);

  /// Total stylist earnings for this service = commission earned + tip
  double get totalEarnings => effectiveCommission + tip;

  /// User-facing notes with hidden commission metadata stripped out
  String? get displayNotes {
    if (notes == null) return null;
    final split = notes!.split('__COMM_META__');
    final clean = split.first.trim();
    return clean.isEmpty ? null : clean;
  }

  factory BarberRecord.fromJson(Map<String, dynamic> json) {
    final price = (json['price'] as num? ?? 0.0).toDouble();
    final tip = (json['tip'] as num? ?? 0.0).toDouble();
    double commRate = (json['commission_rate'] as num? ?? 40.0).toDouble();
    double? commAmount = (json['commission_amount'] as num?)?.toDouble() ??
        (json['commission'] as num?)?.toDouble();

    final rawNotes = json['notes'] as String?;
    if (rawNotes != null && rawNotes.contains('__COMM_META__')) {
      try {
        final split = rawNotes.split('__COMM_META__');
        if (split.length > 1) {
          final meta = jsonDecode(split[1]);
          if (meta is Map<String, dynamic>) {
            if (meta['commission_rate'] != null) {
              commRate = (meta['commission_rate'] as num).toDouble();
            }
            if (meta['commission_amount'] != null) {
              commAmount = (meta['commission_amount'] as num).toDouble();
            }
          }
        }
      } catch (_) {}
    }
    commAmount ??= (price * commRate) / 100.0;

    return BarberRecord(
      id: json['id'] as String,
      branchCode: json['branch_code'] as String? ?? 'MAIN',
      customerName: json['customer_name'] as String? ?? 'Client',
      customerPhone: json['customer_phone'] as String? ?? '',
      service: json['service'] as String? ?? 'Haircut',
      serviceCategory: json['service_category'] as String? ?? BarberRecord.categorizeService(json['service'] as String? ?? ''),
      barber: json['barber'] as String? ?? 'Stylist',
      attendant: json['attendant'] as String? ?? 'Staff',
      price: price,
      tip: tip,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? (price + tip),
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      saleId: json['sale_id'] as String?,
      queueId: json['queue_id'] as String?,
      appointmentId: json['appointment_id'] as String?,
      source: json['source'] as String? ?? 'Queue',
      notes: json['notes'] as String?,
      commissionRate: commRate,
      commissionAmount: commAmount,
    );
  }

  Map<String, dynamic> toJson() {
    final cleanNotes = notes?.split('__COMM_META__').first.trim();
    final metaStr = jsonEncode({
      'commission_rate': commissionRate,
      'commission_amount': effectiveCommission,
    });
    final embeddedNotes = (cleanNotes != null && cleanNotes.isNotEmpty)
        ? '$cleanNotes __COMM_META__$metaStr'
        : '__COMM_META__$metaStr';

    return {
      'id': id,
      'branch_code': branchCode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'service': service,
      'service_category': serviceCategory,
      'barber': barber,
      'attendant': attendant,
      'price': price,
      'tip': tip,
      'total_paid': totalPaid,
      'payment_method': paymentMethod,
      'timestamp': timestamp.toIso8601String(),
      if (saleId != null) 'sale_id': saleId,
      if (queueId != null) 'queue_id': queueId,
      if (appointmentId != null) 'appointment_id': appointmentId,
      'source': source,
      'notes': embeddedNotes,
      'commission_rate': commissionRate,
      'commission_amount': effectiveCommission,
    };
  }

  /// Generates a DB-safe JSON that safely preserves metadata in notes
  /// without failing if remote Supabase doesn't have custom columns yet
  Map<String, dynamic> toDbJson() {
    final map = Map<String, dynamic>.from(toJson());
    map.remove('commission_rate');
    map.remove('commission_amount');
    return map;
  }

  BarberRecord copyWith({
    String? id,
    String? branchCode,
    String? customerName,
    String? customerPhone,
    String? service,
    String? serviceCategory,
    String? barber,
    String? attendant,
    double? price,
    double? tip,
    double? totalPaid,
    String? paymentMethod,
    DateTime? timestamp,
    String? saleId,
    String? queueId,
    String? appointmentId,
    String? source,
    String? notes,
    double? commissionRate,
    double? commissionAmount,
  }) {
    return BarberRecord(
      id: id ?? this.id,
      branchCode: branchCode ?? this.branchCode,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      service: service ?? this.service,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      barber: barber ?? this.barber,
      attendant: attendant ?? this.attendant,
      price: price ?? this.price,
      tip: tip ?? this.tip,
      totalPaid: totalPaid ?? this.totalPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
      saleId: saleId ?? this.saleId,
      queueId: queueId ?? this.queueId,
      appointmentId: appointmentId ?? this.appointmentId,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
    );
  }

  static String categorizeService(String serviceName) {
    final s = serviceName.toLowerCase();
    if (s.contains('shave') || s.contains('beard') || s.contains('mustache') || s.contains('chin')) {
      return 'Shaves & Beard';
    }
    if (s.contains('kid') || s.contains('child') || s.contains('boy') || s.contains('toddler')) {
      return 'Kids Haircut';
    }
    if (s.contains('dye') || s.contains('black') || s.contains('color') || s.contains('tint')) {
      return 'Dye & Color';
    }
    if (s.contains('facial') || s.contains('scrub') || s.contains('steam') || s.contains('wash') || s.contains('shampoo')) {
      return 'Facials & Wash';
    }
    return 'Haircuts';
  }
}

/// Comprehensive summary of a barber's performance, commissions, and tips
class BarberCommissionSummary {
  final String barberName;
  final int totalServices;
  final double grossSales;
  final double totalCommission;
  final double totalTips;
  final double totalEarnings;
  final double effectiveCommissionRate;
  final Map<String, int> servicesByType;
  final List<BarberRecord> records;

  BarberCommissionSummary({
    required this.barberName,
    required this.totalServices,
    required this.grossSales,
    required this.totalCommission,
    required this.totalTips,
    required this.totalEarnings,
    this.effectiveCommissionRate = 40.0,
    this.servicesByType = const {},
    this.records = const [],
  });

  factory BarberCommissionSummary.fromRecords(String barberName, List<BarberRecord> records) {
    final int totalServices = records.length;
    double grossSales = 0.0;
    double totalCommission = 0.0;
    double totalTips = 0.0;
    final Map<String, int> servicesByType = {};

    for (final r in records) {
      grossSales += r.price;
      totalCommission += r.effectiveCommission;
      totalTips += r.tip;
      final cat = r.serviceCategory.isNotEmpty ? r.serviceCategory : BarberRecord.categorizeService(r.service);
      servicesByType[cat] = (servicesByType[cat] ?? 0) + 1;
    }

    final double effectiveRate = grossSales > 0 ? ((totalCommission / grossSales) * 100.0) : 40.0;

    return BarberCommissionSummary(
      barberName: barberName,
      totalServices: totalServices,
      grossSales: grossSales,
      totalCommission: totalCommission,
      totalTips: totalTips,
      totalEarnings: totalCommission + totalTips,
      effectiveCommissionRate: effectiveRate,
      servicesByType: servicesByType,
      records: records,
    );
  }
}


class BarberService {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final double commissionPercentage;

  BarberService({
    required this.id,
    required this.name,
    required this.price,
    this.durationMinutes = 30,
    this.commissionPercentage = 40.0,
  });

  factory BarberService.fromJson(Map<String, dynamic> json) {
    return BarberService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num? ?? 0.0).toDouble(),
      durationMinutes: (json['duration_minutes'] as num? ?? 30).toInt(),
      commissionPercentage: (json['commission_percentage'] as num? ?? 40.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
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
}

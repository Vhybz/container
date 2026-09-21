import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/barbershop_models.dart';

class BarbershopServiceNotifier extends StateNotifier<List<BarberService>> {
  BarbershopServiceNotifier() : super([
    BarberService(id: 'S1', name: 'Executive Haircut', price: 50.0, durationMinutes: 30, commissionAmount: 20.0),
    BarberService(id: 'S2', name: 'Beard Grooming & Oil', price: 30.0, durationMinutes: 20, commissionAmount: 12.0),
    BarberService(id: 'S3', name: 'Hair Dye / Blackening', price: 45.0, durationMinutes: 35, commissionAmount: 15.0),
    BarberService(id: 'S4', name: 'Facial Scrub & Steam', price: 60.0, durationMinutes: 40, commissionAmount: 25.0),
  ]);

  void addService(BarberService service) {
    state = [...state, service];
  }

  /// Finds fixed commission amount for a given service name
  double getCommissionAmount(String serviceName) {
    final sName = serviceName.trim().toLowerCase();
    for (final s in state) {
      if (s.name.toLowerCase() == sName || sName.contains(s.name.toLowerCase()) || s.name.toLowerCase().contains(sName)) {
        return s.commissionAmount;
      }
    }
    return 20.0; // Default fixed commission amount
  }

  /// Backward-compatible percentage lookup
  double getCommissionPercentage(String serviceName) {
    final sName = serviceName.trim().toLowerCase();
    for (final s in state) {
      if (s.name.toLowerCase() == sName || sName.contains(s.name.toLowerCase()) || s.name.toLowerCase().contains(sName)) {
        return s.commissionPercentage;
      }
    }
    return 40.0;
  }
}

final barberServicesProvider = StateNotifierProvider<BarbershopServiceNotifier, List<BarberService>>((ref) {
  return BarbershopServiceNotifier();
});

class AppointmentQueueNotifier extends StateNotifier<List<AppointmentQueue>> {
  AppointmentQueueNotifier() : super([]);

  void addToQueue(AppointmentQueue item) {
    state = [...state, item];
  }

  void updateStatus(String id, String status) {
    state = state.map((q) {
      if (q.id == id) {
        return AppointmentQueue(
          id: q.id,
          customerName: q.customerName,
          serviceName: q.serviceName,
          assignedBarberId: q.assignedBarberId,
          assignedBarberName: q.assignedBarberName,
          scheduledTime: q.scheduledTime,
          status: status,
        );
      }
      return q;
    }).toList();
  }
}

final appointmentQueueProvider = StateNotifierProvider<AppointmentQueueNotifier, List<AppointmentQueue>>((ref) {
  return AppointmentQueueNotifier();
});

class BarberCommissionNotifier extends StateNotifier<List<BarberCommissionLog>> {
  BarberCommissionNotifier() : super([]);

  void logCommission(BarberCommissionLog log) {
    state = [log, ...state];
  }
}

final barberCommissionsProvider = StateNotifierProvider<BarberCommissionNotifier, List<BarberCommissionLog>>((ref) {
  return BarberCommissionNotifier();
});

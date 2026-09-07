import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/barbershop_models.dart';

class BarbershopServiceNotifier extends StateNotifier<List<BarberService>> {
  BarbershopServiceNotifier() : super([
    BarberService(id: 'S1', name: 'Executive Haircut', price: 50.0, durationMinutes: 30, commissionPercentage: 40.0),
    BarberService(id: 'S2', name: 'Beard Grooming & Oil', price: 30.0, durationMinutes: 20, commissionPercentage: 40.0),
    BarberService(id: 'S3', name: 'Hair Dye / Blackening', price: 45.0, durationMinutes: 35, commissionPercentage: 35.0),
    BarberService(id: 'S4', name: 'Facial Scrub & Steam', price: 60.0, durationMinutes: 40, commissionPercentage: 45.0),
  ]);

  void addService(BarberService service) {
    state = [...state, service];
  }
}

final barberServicesProvider = StateNotifierProvider<BarbershopServiceNotifier, List<BarberService>>((ref) {
  return BarbershopServiceNotifier();
});

class AppointmentQueueNotifier extends StateNotifier<List<AppointmentQueue>> {
  AppointmentQueueNotifier() : super([
    AppointmentQueue(id: 'Q-01', customerName: 'Kofi Badu', serviceName: 'Executive Haircut', assignedBarberId: 'B-01', assignedBarberName: 'Master Barber Frank', scheduledTime: '10:15 AM', status: 'In Service'),
    AppointmentQueue(id: 'Q-02', customerName: 'Yaw Boateng', serviceName: 'Beard Grooming', assignedBarberId: 'B-02', assignedBarberName: 'Barber Alex', scheduledTime: '10:30 AM', status: 'Waiting'),
  ]);

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
  BarberCommissionNotifier() : super([
    BarberCommissionLog(id: 'C-101', barberId: 'B-01', barberName: 'Master Barber Frank', serviceName: 'Executive Haircut', saleAmount: 50.0, commissionEarned: 20.0, tipAmount: 10.0),
    BarberCommissionLog(id: 'C-102', barberId: 'B-02', barberName: 'Barber Alex', serviceName: 'Beard Grooming', saleAmount: 30.0, commissionEarned: 12.0, tipAmount: 5.0),
  ]);

  void logCommission(BarberCommissionLog log) {
    state = [log, ...state];
  }
}

final barberCommissionsProvider = StateNotifierProvider<BarberCommissionNotifier, List<BarberCommissionLog>>((ref) {
  return BarberCommissionNotifier();
});

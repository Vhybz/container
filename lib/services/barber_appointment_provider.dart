import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/supabase_config.dart';
import '../models/barbershop_models.dart';
import 'user_provider.dart';
import 'barber_queue_provider.dart';
import 'sms_service.dart';

class BarberAppointmentNotifier extends StateNotifier<List<BarberAppointment>> {
  final Ref ref;
  static const String _boxName = 'barber_appointments_box';
  Timer? _scheduleWatcherTimer;
  bool _isProcessingQueue = false;

  BarberAppointmentNotifier(this.ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    await _fetchFromSupabase();
    _startScheduleWatcher();
    // Run an immediate check on startup
    checkAndProcess30MinAutoQueue();
  }

  void _startScheduleWatcher() {
    _scheduleWatcherTimer?.cancel();
    // Check every 30 seconds for upcoming appointments reaching the 30-min threshold
    _scheduleWatcherTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkAndProcess30MinAutoQueue();
    });
  }

  Future<void> _loadFromCache() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final rawList = box.get('appointments_list');
      if (rawList != null) {
        final List decoded = jsonDecode(rawList);
        final loaded = decoded
            .map((e) => BarberAppointment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading barber appointments from cache: $e');
    }
  }

  Future<void> _saveToCache(List<BarberAppointment> list) async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
      await box.put('appointments_list', jsonStr);
    } catch (e) {
      debugPrint('Error saving barber appointments to cache: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      final response = await SupabaseConfig.client
          .from('barber_appointments')
          .select()
          .order('appointment_time', ascending: true)
          .limit(100);

      final List data = response as List? ?? [];
      if (data.isNotEmpty) {
        final remoteList = data
            .map((e) => BarberAppointment.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Merge remote with local to preserve newly created items
        final Map<String, BarberAppointment> map = {
          for (var item in state) item.id: item,
        };
        for (var remote in remoteList) {
          map[remote.id] = remote;
        }
        final merged = map.values.toList()
          ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
        state = merged;
        await _saveToCache(merged);
      }
    } catch (e) {
      debugPrint('Supabase barber appointments fetch notice: $e');
    }
  }

  Future<BarberAppointment> bookAppointment({
    required String customerName,
    required String phone,
    required String service,
    required String barber,
    required DateTime appointmentTime,
    int durationMinutes = 30,
    double? price,
    String? customerId,
    String? notes,
    String? momoNumber,
    String? momoName,
  }) async {
    final user = ref.read(currentUserProvider);
    final String appointmentId = 'APT-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(4, '0')}';
    final double finalPrice = price ?? BarberQueueNotifier.getDefaultPrice(service);

    final appointment = BarberAppointment(
      id: appointmentId,
      branchCode: user?.branchCode ?? 'MAIN',
      customerId: customerId,
      customerName: customerName.trim(),
      phone: phone.trim(),
      service: service,
      barber: barber,
      appointmentTime: appointmentTime,
      durationMinutes: durationMinutes,
      price: finalPrice,
      status: 'Pending Payment',
      paymentStatus: 'Pending',
      isQueued: false,
      reminderSent: false,
      notes: notes?.trim(),
      momoNumber: (momoNumber != null && momoNumber.trim().isNotEmpty) ? momoNumber.trim() : null,
      momoName: (momoName != null && momoName.trim().isNotEmpty) ? momoName.trim() : null,
      bookedBy: user != null ? '${user.firstName} ${user.surname} (${user.role.name})' : 'Staff',
      createdAt: DateTime.now(),
    );

    // Save locally
    final updatedList = [appointment, ...state]
      ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    state = updatedList;
    await _saveToCache(updatedList);

    // 1. Dispatch immediate Booking Confirmation SMS with MoMo payment instructions FIRST
    if (phone.trim().isNotEmpty) {
      debugPrint('Barber Appointment: Dispatching immediate booking MoMo payment SMS to ${phone.trim()}...');
      SmsService.sendAppointmentBookingSms(
        name: customerName.trim(),
        phone: phone.trim(),
        serviceName: service,
        barberName: barber,
        appointmentTime: appointmentTime,
        appointmentId: appointmentId,
        price: finalPrice,
        momoNumber: appointment.effectiveMomoNumber,
        momoName: appointment.effectiveMomoName,
      );
    }

    // 2. Sync to Supabase in background
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client.from('barber_appointments').upsert(appointment.toJson());
      }
    } catch (e) {
      debugPrint('Supabase appointment booking error: $e');
    }

    // Note: Do not auto-queue pending payment appointments until validated
    return appointment;
  }

  /// Validates an appointment after MoMo payment is verified.
  /// Updates status to 'Scheduled' and paymentStatus to 'Validated',
  /// saves changes, dispatches confirmation SMS to the client, and evaluates auto-queueing.
  Future<bool> validateAppointment(String appointmentId) async {
    final index = state.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return false;

    final apt = state[index];
    final validatedApt = apt.copyWith(
      status: 'Scheduled',
      paymentStatus: 'Validated',
      validatedAt: DateTime.now(),
    );

    state = state.map((a) => a.id == appointmentId ? validatedApt : a).toList();
    await _saveToCache(state);

    // Sync to Supabase
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client
            .from('barber_appointments')
            .update({
              'status': 'Scheduled',
              'payment_status': 'Validated',
              'validated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', appointmentId);
      }
    } catch (e) {
      debugPrint('Supabase validate appointment notice: $e');
    }

    // Send Validation Confirmation SMS to client
    if (apt.phone.trim().isNotEmpty) {
      await SmsService.sendAppointmentValidatedSms(
        name: apt.customerName,
        phone: apt.phone.trim(),
        serviceName: apt.service,
        barberName: apt.barber,
        appointmentTime: apt.appointmentTime,
        appointmentId: apt.id,
      );
    }

    // Check if appointment is due for queueing (e.g. booked for within next 30 mins)
    await checkAndProcess30MinAutoQueue();

    return true;
  }

  /// Evaluates all scheduled appointments and auto-adds to queue when within 30 minutes
  Future<void> checkAndProcess30MinAutoQueue() async {
    if (_isProcessingQueue || !mounted) return;
    _isProcessingQueue = true;

    try {
      final now = DateTime.now();
      bool hasChanges = false;
      final List<BarberAppointment> updatedList = [];

      for (var apt in state) {
        // Only target appointments that are validated (not pending payment) and not yet queued
        if (!apt.isPendingPayment && (apt.status == 'Scheduled' || apt.status == 'Confirmed') && !apt.isQueued) {
          final thirtyMinsPrior = apt.appointmentTime.subtract(const Duration(minutes: 30));
          final fourHoursAfter = apt.appointmentTime.add(const Duration(hours: 4));

          // If current time is within or past 30 mins prior, and not expired long ago
          if (now.isAfter(thirtyMinsPrior) && now.isBefore(fourHoursAfter)) {
            debugPrint('Auto-Queueing appointment ${apt.id} for ${apt.customerName} (Due at ${apt.appointmentTime})');

            // 1. Add to BarberQueue
            await ref.read(barberQueueProvider.notifier).addToQueue(
              customer: apt.customerName,
              phone: apt.phone,
              service: apt.service,
              barber: apt.barber,
              price: apt.price,
              isAppointment: true,
              appointmentId: apt.id,
              appointmentTime: apt.appointmentTime,
              sendSms: false, // Send specialized 30-min reminder SMS below
            );

            // 2. Dispatch 30-minute Reminder SMS
            if (apt.phone.trim().isNotEmpty) {
              await SmsService.sendAppointmentReminder30MinSms(
                name: apt.customerName,
                phone: apt.phone.trim(),
                serviceName: apt.service,
                barberName: apt.barber,
                appointmentTime: apt.appointmentTime,
              );
            }

            // 3. Mark appointment as Queued
            final updatedApt = apt.copyWith(
              isQueued: true,
              status: 'Queued',
              reminderSent: true,
            );
            updatedList.add(updatedApt);
            hasChanges = true;

            // Sync update to Supabase
            try {
              final connectivity = await Connectivity().checkConnectivity();
              if (!connectivity.contains(ConnectivityResult.none)) {
                await SupabaseConfig.client
                    .from('barber_appointments')
                    .update({'status': 'Queued', 'is_queued': true, 'reminder_sent': true})
                    .eq('id', apt.id);
              }
            } catch (e) {
              debugPrint('Supabase appointment auto-queue update notice: $e');
            }
            continue;
          }
        }
        updatedList.add(apt);
      }

      if (hasChanges && mounted) {
        state = updatedList;
        await _saveToCache(updatedList);
      }
    } catch (e) {
      debugPrint('Error in checkAndProcess30MinAutoQueue: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Allows Secretary or Admin to manually push an appointment to queue ahead of time
  Future<void> manualQueueNow(String appointmentId) async {
    final index = state.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final apt = state[index];
    if (apt.isQueued) return;

    // 1. Add to live queue
    await ref.read(barberQueueProvider.notifier).addToQueue(
      customer: apt.customerName,
      phone: apt.phone,
      service: apt.service,
      barber: apt.barber,
      price: apt.price,
      isAppointment: true,
      appointmentId: apt.id,
      appointmentTime: apt.appointmentTime,
      sendSms: false,
    );

    // 2. Dispatch reminder SMS
    if (apt.phone.trim().isNotEmpty) {
      await SmsService.sendAppointmentReminder30MinSms(
        name: apt.customerName,
        phone: apt.phone.trim(),
        serviceName: apt.service,
        barberName: apt.barber,
        appointmentTime: apt.appointmentTime,
      );
    }

    // 3. Update appointment status
    final updatedApt = apt.copyWith(
      isQueued: true,
      status: 'Queued',
      paymentStatus: 'Validated',
      validatedAt: apt.validatedAt ?? DateTime.now(),
      reminderSent: true,
    );

    state = state.map((a) => a.id == appointmentId ? updatedApt : a).toList();
    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client
            .from('barber_appointments')
            .update({'status': 'Queued', 'is_queued': true, 'reminder_sent': true, 'payment_status': 'Validated'})
            .eq('id', appointmentId);
      }
    } catch (e) {
      debugPrint('Supabase manual queue update error: $e');
    }
  }

  Future<void> cancelAppointment(String appointmentId) async {
    state = state.map((a) {
      if (a.id == appointmentId) {
        return a.copyWith(status: 'Cancelled');
      }
      return a;
    }).toList();

    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client
            .from('barber_appointments')
            .update({'status': 'Cancelled'})
            .eq('id', appointmentId);
      }
    } catch (e) {
      debugPrint('Supabase cancel appointment error: $e');
    }
  }

  Future<void> rescheduleAppointment(String appointmentId, DateTime newTime) async {
    final index = state.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return;

    final apt = state[index];
    final updatedApt = apt.copyWith(
      appointmentTime: newTime,
      status: 'Scheduled',
      isQueued: false,
      reminderSent: false,
    );

    state = state.map((a) => a.id == appointmentId ? updatedApt : a).toList()
      ..sort((a, b) => a.appointmentTime.compareTo(b.appointmentTime));
    await _saveToCache(state);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await SupabaseConfig.client
            .from('barber_appointments')
            .update({
              'appointment_time': newTime.toIso8601String(),
              'status': 'Scheduled',
              'is_queued': false,
              'reminder_sent': false,
            })
            .eq('id', appointmentId);
      }
    } catch (e) {
      debugPrint('Supabase reschedule appointment error: $e');
    }

    // Send updated confirmation SMS
    if (apt.phone.trim().isNotEmpty) {
      await SmsService.sendAppointmentBookingSms(
        name: apt.customerName,
        phone: apt.phone,
        serviceName: apt.service,
        barberName: apt.barber,
        appointmentTime: newTime,
        appointmentId: apt.id,
        price: apt.price,
        momoNumber: apt.effectiveMomoNumber,
        momoName: apt.effectiveMomoName,
      );
    }
  }

  @override
  void dispose() {
    _scheduleWatcherTimer?.cancel();
    super.dispose();
  }
}

final barberAppointmentsProvider =
    StateNotifierProvider<BarberAppointmentNotifier, List<BarberAppointment>>((ref) {
  return BarberAppointmentNotifier(ref);
});

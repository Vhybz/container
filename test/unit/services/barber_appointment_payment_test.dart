import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/models/barbershop_models.dart';
import 'package:container_business_manager/services/sms_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Barber Appointment MoMo Payment Validation Tests', () {
    final testAppointmentTime = DateTime.now().add(const Duration(minutes: 20));

    test('New BarberAppointment initializes with Pending Payment status and isPendingPayment == true', () {
      final appt = BarberAppointment(
        id: 'APT-1001',
        customerName: 'Kofi Mensah',
        phone: '0551234567',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        appointmentTime: testAppointmentTime,
        price: 50.0,
      );

      expect(appt.status, equals('Pending Payment'));
      expect(appt.paymentStatus, equals('Pending'));
      expect(appt.isPendingPayment, isTrue);
      expect(appt.validatedAt, isNull);
    });

    test('isDueForQueue is FALSE while payment is pending, even if within 30 minutes of appointment', () {
      final appt = BarberAppointment(
        id: 'APT-1002',
        customerName: 'Ama Serwaa',
        phone: '0559876543',
        service: 'Hair Dye / Blackening',
        barber: 'King Mojo',
        appointmentTime: DateTime.now().add(const Duration(minutes: 15)), // within 30 mins
        price: 70.0,
      );

      // Even though time is within 30 mins, it should NOT be due for queue until validated
      expect(appt.isDueForQueue, isFalse);
    });

    test('Validating appointment updates status to Scheduled/Validated and enables queue eligibility', () {
      final appt = BarberAppointment(
        id: 'APT-1003',
        customerName: 'Kwame Nkrumah',
        phone: '0241112233',
        service: 'Beard Grooming & Oil',
        barber: 'King Mojo',
        appointmentTime: DateTime.now().add(const Duration(minutes: 15)),
        price: 35.0,
      );

      // Validate payment
      final validatedAt = DateTime.now();
      final validatedAppt = appt.copyWith(
        status: 'Scheduled',
        paymentStatus: 'Validated',
        validatedAt: validatedAt,
      );

      expect(validatedAppt.status, equals('Scheduled'));
      expect(validatedAppt.paymentStatus, equals('Validated'));
      expect(validatedAppt.isPendingPayment, isFalse);
      expect(validatedAppt.validatedAt, equals(validatedAt));
      // Now that it's validated and within 30 mins, it is due for queue
      expect(validatedAppt.isDueForQueue, isTrue);
    });

    test('JSON serialization & deserialization retains payment_status and validated_at', () {
      final now = DateTime.now();
      final appt = BarberAppointment(
        id: 'APT-1004',
        customerName: 'Yaw Boateng',
        phone: '0505556677',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        appointmentTime: now.add(const Duration(hours: 2)),
        price: 60.0,
        status: 'Scheduled',
        paymentStatus: 'Validated',
        validatedAt: now,
      );

      final json = appt.toJson();
      expect(json['status'], equals('Scheduled'));
      expect(json['payment_status'], equals('Validated'));
      expect(json['validated_at'], isNotNull);

      final deserialized = BarberAppointment.fromJson(json);
      expect(deserialized.id, equals(appt.id));
      expect(deserialized.status, equals('Scheduled'));
      expect(deserialized.paymentStatus, equals('Validated'));
      expect(deserialized.isPendingPayment, isFalse);
      expect(deserialized.validatedAt, isNotNull);
    });

    test('Booking and Validation SMS functions execute safely without crashing', () async {
      // Empty phone returns false safely
      final emptyBooking = await SmsService.sendAppointmentBookingSms(
        name: 'Test Client',
        phone: '',
        serviceName: 'Haircut',
        barberName: 'King Mojo',
        appointmentTime: DateTime.now(),
        price: 40.0,
      );
      expect(emptyBooking, isFalse);

      final emptyValidation = await SmsService.sendAppointmentValidatedSms(
        name: 'Test Client',
        phone: '',
        serviceName: 'Haircut',
        barberName: 'King Mojo',
        appointmentTime: DateTime.now(),
      );
      expect(emptyValidation, isFalse);
    });

    test('BarberAppointment defaults effective MoMo details to 0552857861 and Emmanuel ADU Adjei', () {
      final appt = BarberAppointment(
        id: 'APT-1005',
        customerName: 'Kofi Mensah',
        phone: '0240000000',
        service: 'Executive Haircut',
        barber: 'King Mojo',
        appointmentTime: DateTime.now(),
        price: 50.0,
      );

      expect(appt.effectiveMomoNumber, equals('0552857861'));
      expect(appt.effectiveMomoName, equals('Emmanuel ADU Adjei'));
    });

    test('BarberAppointment custom momoNumber and momoName serialize and deserialize correctly', () {
      final appt = BarberAppointment(
        id: 'APT-1006',
        customerName: 'Akua Osei',
        phone: '0241234567',
        service: 'Beard Grooming',
        barber: 'King Mojo',
        appointmentTime: DateTime.now(),
        price: 35.0,
        momoNumber: '0244112233',
        momoName: 'Boss Barbershop MTN',
      );

      expect(appt.effectiveMomoNumber, equals('0244112233'));
      expect(appt.effectiveMomoName, equals('Boss Barbershop MTN'));

      final json = appt.toJson();
      expect(json['momo_number'], equals('0244112233'));
      expect(json['momo_name'], equals('Boss Barbershop MTN'));

      final deserialized = BarberAppointment.fromJson(json);
      expect(deserialized.momoNumber, equals('0244112233'));
      expect(deserialized.momoName, equals('Boss Barbershop MTN'));
      expect(deserialized.effectiveMomoNumber, equals('0244112233'));
      expect(deserialized.effectiveMomoName, equals('Boss Barbershop MTN'));
    });

    test('SmsService formatMomoInstructions guarantees inclusion of MoMo number and name', () {
      final defaultInstruction = SmsService.formatMomoInstructions();
      expect(defaultInstruction, contains('0552857861'));
      expect(defaultInstruction, contains('Emmanuel ADU Adjei'));

      final customInstruction = SmsService.formatMomoInstructions(
        momoNumber: '0200000001',
        momoName: 'Shop Manager',
      );
      expect(customInstruction, contains('0200000001'));
      expect(customInstruction, contains('Shop Manager'));
    });
  });
}

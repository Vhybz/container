import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/services/app_settings_provider.dart';
import 'package:container_business_manager/models/user_model.dart';

bool evaluatePasscodeBypass({
  required bool requirePasscode,
  required String? userPasscode,
  required bool unlocked,
  required bool isLockedDown,
}) {
  if (isLockedDown) {
    return unlocked;
  }
  if (!requirePasscode) return true;
  if (userPasscode == null || userPasscode.isEmpty) return true;
  return unlocked;
}

void main() {
  group('Passcode & PIN Toggle Logic Tests', () {
    test('AppSettings defaults requirePasscode to false', () {
      final settings = AppSettings();
      expect(settings.requirePasscode, isFalse);
    });

    test('AppSettings copyWith correctly updates requirePasscode', () {
      final settings = AppSettings();
      final updated = settings.copyWith(requirePasscode: true);
      expect(updated.requirePasscode, isTrue);

      final toggledBack = updated.copyWith(requirePasscode: false);
      expect(toggledBack.requirePasscode, isFalse);
    });

    test('Bypass check passes when requirePasscode is false', () {
      final settings = AppSettings(requirePasscode: false);
      final user = UserAccount(
        id: 'user-1',
        firstName: 'Ama',
        surname: 'Boateng',
        email: 'ama@store.com',
        role: UserRole.cashier,
        passcode: '1234',
      );

      final shouldBypass = evaluatePasscodeBypass(
        requirePasscode: settings.requirePasscode,
        userPasscode: user.passcode,
        unlocked: false,
        isLockedDown: false,
      );

      expect(shouldBypass, isTrue, reason: 'When requirePasscode is false, PIN screen should not appear');
    });

    test('Bypass check passes when user has no configured passcode', () {
      final settings = AppSettings(requirePasscode: true);
      final user = UserAccount(
        id: 'user-2',
        firstName: 'Kofi',
        surname: 'Mensah',
        email: 'kofi@store.com',
        role: UserRole.pharmacist,
        passcode: null, // No passcode set
      );

      final shouldBypass = evaluatePasscodeBypass(
        requirePasscode: settings.requirePasscode,
        userPasscode: user.passcode,
        unlocked: false,
        isLockedDown: false,
      );

      expect(shouldBypass, isTrue, reason: 'Users without a passcode should not be locked out');
    });

    test('Enforcement triggers only when requirePasscode is true, user has passcode, and session is locked', () {
      final settings = AppSettings(requirePasscode: true);
      final user = UserAccount(
        id: 'user-3',
        firstName: 'Yaw',
        surname: 'Osei',
        email: 'yaw@store.com',
        role: UserRole.admin,
        passcode: '4321',
      );

      final shouldBypass = evaluatePasscodeBypass(
        requirePasscode: settings.requirePasscode,
        userPasscode: user.passcode,
        unlocked: false,
        isLockedDown: false,
      );

      expect(shouldBypass, isFalse, reason: 'PIN screen MUST appear when requirePasscode is true and session is locked');
    });

    test('Emergency lockdown strictly enforces lock even if requirePasscode is false', () {
      final settings = AppSettings(requirePasscode: false);
      final user = UserAccount(
        id: 'user-4',
        firstName: 'Super',
        surname: 'Admin',
        email: 'admin@store.com',
        role: UserRole.superAdmin,
        passcode: '9999',
      );

      final shouldBypass = evaluatePasscodeBypass(
        requirePasscode: settings.requirePasscode,
        userPasscode: user.passcode,
        unlocked: false,
        isLockedDown: true,
      );

      expect(shouldBypass, isFalse, reason: 'Emergency lockdown overrides toggle and requires unlock');
    });
  });
}

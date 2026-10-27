import 'package:flutter_test/flutter_test.dart';
import 'package:container_business_manager/services/sms_service.dart';

void main() {
  group('SmsService Phone Number Formatting Tests', () {
    test('Standard 10-digit Ghana number converts to 233 format', () {
      expect(SmsService.formatPhoneNumber('0244123456'), equals('233244123456'));
      expect(SmsService.formatPhoneNumber('0552857861'), equals('233552857861'));
      expect(SmsService.formatPhoneNumber('0209276200'), equals('233209276200'));
    });

    test('International prefix +233 converts cleanly', () {
      expect(SmsService.formatPhoneNumber('+233244123456'), equals('233244123456'));
      expect(SmsService.formatPhoneNumber('+233 24 412 3456'), equals('233244123456'));
    });

    test('Extra leading zero after 233 country code (2330...) is stripped', () {
      expect(SmsService.formatPhoneNumber('2330244123456'), equals('233244123456'));
      expect(SmsService.formatPhoneNumber('+2330244123456'), equals('233244123456'));
      expect(SmsService.formatPhoneNumber('002330244123456'), equals('233244123456'));
    });

    test('Double zero country code 00233 converts cleanly', () {
      expect(SmsService.formatPhoneNumber('00233244123456'), equals('233244123456'));
    });

    test('9-digit national number gets prefixed with 233', () {
      expect(SmsService.formatPhoneNumber('244123456'), equals('233244123456'));
    });

    test('Empty or invalid phone returns empty string', () {
      expect(SmsService.formatPhoneNumber(''), equals(''));
      expect(SmsService.formatPhoneNumber('  '), equals(''));
    });
  });
}

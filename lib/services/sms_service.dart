import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';
import '../models/user_model.dart';

class SmsService {
  // Use const for better Web support with --dart-define
  static const String _defineApiKey = String.fromEnvironment('ARKESEL_API_KEY');
  static const String _defineSenderId = String.fromEnvironment('ARKESEL_SENDER_ID');
  static const String _defineAdminPhone = String.fromEnvironment('ADMIN_PHONE');

  static String get _apiKey {
    if (_defineApiKey.isNotEmpty) return _defineApiKey;
    return dotenv.env['ARKESEL_API_KEY'] ?? 'akhlSEFORkpBSHBNR1JQTk1Lbm4';
  }
  
  static String get _senderId {
    if (_defineSenderId.isNotEmpty) return _defineSenderId;
    return dotenv.env['ARKESEL_SENDER_ID'] ?? 'Container';
  }

  static String get _adminPhone {
    if (_defineAdminPhone.isNotEmpty) return _defineAdminPhone;
    return dotenv.env['ADMIN_PHONE'] ?? '0209276200';
  }

  static String formatPhoneNumber(String phone) {
    String clean = phone.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) return '';

    // If starts with international 00233
    if (clean.startsWith('00233')) {
      clean = clean.substring(2);
    }

    // If starts with 2330 (e.g. 2330244123456 - 13 digits with extra zero after country code)
    if (clean.startsWith('2330') && clean.length == 13) {
      clean = '233${clean.substring(4)}';
    }

    // If starts with 0 and length is 10 (e.g. 0244123456)
    if (clean.startsWith('0') && clean.length == 10) {
      clean = '233${clean.substring(1)}';
    }

    // If 9 digits (e.g. 244123456)
    if (clean.length == 9 && !clean.startsWith('233')) {
      clean = '233$clean';
    }

    return clean;
  }

  static Future<bool> _sendSms(String to, String message, {String? customSenderId}) async {
    final apiKey = _apiKey.trim();
    final defaultSender = _senderId.trim().isNotEmpty ? _senderId.trim() : 'Container';
    String senderId = (customSenderId != null && customSenderId.trim().isNotEmpty)
        ? customSenderId.trim()
        : defaultSender;

    // Enforce 11 character max limit for SMS Sender ID per telecom standards
    if (senderId.length > 11) {
      senderId = senderId.substring(0, 11);
    }

    if (apiKey.isEmpty) {
      debugPrint('SMS Engine Error: API Key is missing');
      return false;
    }

    final formattedPhone = formatPhoneNumber(to);
    if (formattedPhone.isEmpty || formattedPhone.length < 9) {
      debugPrint('SMS Engine Error: Formatted recipient phone number is invalid: "$to" -> "$formattedPhone"');
      return false;
    }

    // Auto-Retry Loop: Try up to 3 times across multiple proxy and direct API candidate routes
    for (int attempt = 1; attempt <= 3; attempt++) {
      debugPrint('SMS Engine: Attempt $attempt/3 for $formattedPhone...');

      final v1SenderTarget = 'https://sms.arkesel.com/sms/api?action=send-sms&api_key=${Uri.encodeComponent(apiKey)}&to=$formattedPhone&from=${Uri.encodeComponent(senderId)}&sms=${Uri.encodeComponent(message)}';
      final v1DefaultTarget = 'https://sms.arkesel.com/sms/api?action=send-sms&api_key=${Uri.encodeComponent(apiKey)}&to=$formattedPhone&from=${Uri.encodeComponent(defaultSender)}&sms=${Uri.encodeComponent(message)}';

      // 1. Candidate A (Web): CorsProxy.io V2 POST
      if (kIsWeb) {
        try {
          final response = await http.post(
            Uri.parse('https://corsproxy.io/?https://sms.arkesel.com/api/v2/sms/send'),
            headers: {'api-key': apiKey, 'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'sender': senderId, 'recipients': [formattedPhone], 'message': message}),
          ).timeout(const Duration(seconds: 6));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final body = response.body.toLowerCase();
            if (!body.contains('error') || body.contains('1000') || body.contains('success')) {
              debugPrint('SMS sent successfully via CorsProxy V2 (Attempt $attempt): ${response.body}');
              return true;
            }
          }
        } catch (e) {
          debugPrint('SMS CorsProxy V2 Notice: $e');
        }

        // 2. Candidate B (Web): AllOrigins V1 GET
        try {
          final proxyUrl = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(v1SenderTarget)}');
          final response = await http.get(proxyUrl).timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();
            if (body.contains('"code":"1000"') || body.contains('1000') || body.contains('success') || body.contains('ok')) {
              debugPrint('SMS sent successfully via AllOrigins V1 (Attempt $attempt): ${response.body}');
              return true;
            }
          }
        } catch (e) {
          debugPrint('SMS AllOrigins V1 Notice: $e');
        }

        // 3. Candidate C (Web): CorsProxy.io V1 GET with default sender
        try {
          final proxyUrl = Uri.parse('https://corsproxy.io/?$v1DefaultTarget');
          final response = await http.get(proxyUrl).timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();
            if (body.contains('"code":"1000"') || body.contains('1000') || body.contains('success') || body.contains('ok')) {
              debugPrint('SMS sent successfully via CorsProxy V1 Default (Attempt $attempt): ${response.body}');
              return true;
            }
          }
        } catch (e) {
          debugPrint('SMS CorsProxy V1 Notice: $e');
        }
      }

      // 4. Candidate D: Direct Arkesel V2 POST (For Native Android/iOS/Desktop or Direct Web)
      try {
        final response = await http.post(
          Uri.parse('https://sms.arkesel.com/api/v2/sms/send'),
          headers: {'api-key': apiKey, 'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'sender': senderId, 'recipients': [formattedPhone], 'message': message}),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = response.body.toLowerCase();
          if (!body.contains('error') || body.contains('1000') || body.contains('success')) {
            debugPrint('SMS sent successfully via Direct Arkesel V2 (Attempt $attempt): ${response.body}');
            return true;
          }
        }
      } catch (e) {
        debugPrint('SMS Direct V2 Notice: $e');
      }

      // 5. Candidate E: Direct Arkesel V1 GET
      try {
        final response = await http.get(Uri.parse(v1DefaultTarget)).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final body = response.body.toLowerCase();
          if (body.contains('"code":"1000"') || body.contains('1000') || body.contains('success') || body.contains('ok')) {
            debugPrint('SMS sent successfully via Direct Arkesel V1 (Attempt $attempt): ${response.body}');
            return true;
          }
        }
      } catch (e) {
        debugPrint('SMS Direct V1 Notice: $e');
      }

      // Brief delay before next retry attempt
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    debugPrint('SMS Engine: Failed to send SMS after 3 attempts to $formattedPhone.');
    return false;
  }

  static Future<bool> sendReceiptSms(
    SaleRecord sale, {
    double? discountAmount,
    String? branchName,
    String? customPhone,
  }) async {
    final String? targetPhone = (customPhone != null && customPhone.trim().isNotEmpty)
        ? customPhone.trim()
        : sale.customerPhone;

    if (targetPhone == null || targetPhone.trim().isEmpty) {
      debugPrint('sendReceiptSms: No target phone number provided.');
      return false;
    }

    final bool isDebt = sale.balance > 0.01;
    final String typeHeader = isDebt ? 'DEBT INVOICE' : 'RECEIPT';

    final bool isPharm = sale.items.any((i) => 
      i.product.requiresPrescription || 
      i.product.category.toUpperCase().contains('PHARM') || 
      i.product.category.toUpperCase().contains('DRUG') || 
      i.product.category.toUpperCase().contains('MED') ||
      i.product.category.toUpperCase().contains('ANTIBIOTIC')
    );

    final bool isTechOrBarber = sale.items.any((i) {
      final cat = i.product.category.toUpperCase();
      final name = i.product.name.toUpperCase();
      return cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM') ||
             cat.contains('PHONE') || cat.contains('TECH') || cat.contains('REPAIR') || name.contains('IPHONE');
    });

    final bool showCustomerCare = isTechOrBarber || isPharm;

    final String shopName = branchName ?? (isPharm ? 'Emmanuel Chemist' : 'Container Stores');
    final String senderId = isPharm ? 'EmmaChemist' : 'Container';

    // Format clean receipt ID
    final String receiptId = sale.id.startsWith('INV-')
        ? sale.id
        : (sale.id.length > 8 ? sale.id.substring(sale.id.length - 8).toUpperCase() : sale.id.toUpperCase());

    // Format Item Breakdown
    final String itemsSummary = sale.items.map((i) {
      final qty = i.quantity % 1 == 0 ? i.quantity.toInt().toString() : i.quantity.toStringAsFixed(1);
      final displayImei = i.imei ?? (i.product.imeiList != null && i.product.imeiList!.isNotEmpty ? i.product.imeiList!.first : null);
      final imeiStr = (displayImei != null && displayImei.trim().isNotEmpty) ? ' (IMEI: ${displayImei.trim()})' : '';
      return '$qty${i.product.unit} ${i.product.name}$imeiStr';
    }).join(', ');

    String message = '$typeHeader #$receiptId - $shopName\n';
    final displayName = sale.patientName ?? sale.customerName;
    if (displayName != null && displayName.isNotEmpty && displayName != 'Walk-in Customer' && displayName != 'Walk-In Patient') {
      message += '${isPharm ? "Patient" : "Customer"}: $displayName\n';
    }
    if (itemsSummary.isNotEmpty) {
      message += 'Items: $itemsSummary\n';
    }
    message += 'Total: GHS ${sale.totalAmount.toStringAsFixed(2)}';

    if (isDebt) {
      message += '\nPaid: GHS ${sale.amountPaid.toStringAsFixed(2)}\nBalance Due: GHS ${sale.balance.toStringAsFixed(2)}';
    } else {
      message += '\nStatus: Paid';
      if (sale.effectiveChange > 0.01) {
        message += '\nChange: GHS ${sale.effectiveChange.toStringAsFixed(2)}';
      }
    }

    if (discountAmount != null && discountAmount > 0) {
      message += '\nSaved: GHS ${discountAmount.toStringAsFixed(2)}';
    }

    if (sale.rxNumber != null && sale.rxNumber!.trim().isNotEmpty) {
      message += '\nRx No: ${sale.rxNumber!.trim()}';
    }

    if (sale.doctorName != null && sale.doctorName!.trim().isNotEmpty) {
      message += '\nPrescriber: ${sale.doctorName!.trim()}';
    }

    if (sale.prescription != null && sale.prescription!.trim().isNotEmpty) {
      message += '\nRx / Dosage:\n${sale.prescription!.trim()}';
    }

    if (isPharm) {
      message += '\nThank you for trusting Emmanuel Chemist!';
    } else {
      message += '\nThank you for shopping with us!';
    }

    if (showCustomerCare) {
      message += '\nCustomer Care: +233 53 681 4449';
    }

    return await _sendSms(targetPhone, message, customSenderId: senderId);
  }

  static Future<bool> sendPrescriptionSms({
    required String phone,
    required String patientName,
    required String prescription,
    String? rxNumber,
    String? doctorName,
    String? pharmacistName,
    String? branchName,
  }) async {
    if (phone.trim().isEmpty) {
      debugPrint('sendPrescriptionSms: No recipient phone number provided.');
      return false;
    }

    final String shopName = branchName ?? 'Emmanuel Chemist';
    final String senderId = 'EmmaChemist';

    String message = 'PRESCRIPTION (Rx) - $shopName\n';
    message += 'Patient: $patientName\n';
    message += 'Medication & Dosage:\n${prescription.trim()}\n';
    if (doctorName != null && doctorName.trim().isNotEmpty) {
      message += 'Prescriber: $doctorName\n';
    }
    if (rxNumber != null && rxNumber.trim().isNotEmpty) {
      message += 'Rx No: $rxNumber\n';
    }
    if (pharmacistName != null && pharmacistName.trim().isNotEmpty) {
      message += 'Dispensed by: $pharmacistName\n';
    }
    message += 'Please take medications as directed. Keep out of reach of children.\nTel: 0209276200';

    return await _sendSms(phone, message, customSenderId: senderId);
  }

  static Future<void> sendApprovalRequestSms(UserAccount applicant, List<UserAccount> admins) async {
    final message = 'New user registration needs approval. Name: ${applicant.firstName} ${applicant.surname}, Role: ${applicant.role.name.toUpperCase()}. Please log in to approve.';
    
    final adminPhones = admins
        .where((u) => (u.role == UserRole.admin || u.role == UserRole.superAdmin) && u.phone != null && u.phone!.isNotEmpty)
        .map((u) => u.phone!)
        .toSet()
        .toList();

    if (_adminPhone.isNotEmpty && !adminPhones.contains(_adminPhone)) {
      adminPhones.add(_adminPhone);
    }

    for (final phone in adminPhones) {
      await _sendSms(phone, message);
    }
  }

  static Future<void> sendSignupConfirmationSms(UserAccount user, bool isAutoApproved) async {
    if (user.phone == null || user.phone!.isEmpty) return;

    final statusMessage = isAutoApproved 
        ? 'Your account has been approved. You can now log in.' 
        : 'Your application is pending administrator approval. You will be notified once approved.';

    String message = 'Hello ${user.firstName}, thank you for registering with Container Stores. $statusMessage';
    
    if (user.role == UserRole.admin && user.branchCode != null) {
      message += ' Your Shop Registration Code is: ${user.branchCode}. Please share this with your staff to link them to your branch.';
    }
    
    await _sendSms(user.phone!, message);
  }

  static Future<void> sendStaffOnboardingSms(UserAccount user) async {
    if (user.phone == null || user.phone!.isEmpty) return;
    final String message = 'Welcome to the team, ${user.firstName}! Your account has been linked to your staff profile as a ${user.role.name.toUpperCase()} at Container Stores. You can now log in and start working.';
    await _sendSms(user.phone!, message);
  }

  static Future<void> sendApprovalSms(UserAccount user) async {
    if (user.phone == null || user.phone!.isEmpty) return;
    final String message = 'Congratulations ${user.firstName}! Your Container Stores account has been approved. You can now log in instantly.';
    await _sendSms(user.phone!, message);
  }

  static Future<void> sendCustomerWelcomeSms(String name, String phone, String? branchName) async {
    if (phone.isEmpty) return;
    final String branchText = branchName != null ? '($branchName Branch)' : '';
    final String message = 'Hello $name, thank you for being a valued customer at Container Stores $branchText.';
    await _sendSms(phone, message);
  }

  static Future<void> sendDebtReminderSms(SaleRecord sale, {String? branchName}) async {
    if (sale.customerPhone == null || sale.customerPhone!.isEmpty) return;
    final String shopName = branchName ?? 'Container Stores';
    final String message = 'DEBT REMINDER: Hello ${sale.customerName}, this is a reminder regarding your outstanding balance of GHC${sale.balance.toStringAsFixed(2)} for invoice ${sale.id} at $shopName. Please settle as soon as possible.';
    await _sendSms(sale.customerPhone!, message);
  }

  static Future<bool> sendDebtPaymentSms({
    required String phone,
    required String name,
    required String invoiceId,
    required double amountPaid,
    required double remainingBalance,
    String? branchName,
  }) async {
    if (phone.isEmpty) return false;
    final String shopName = branchName ?? 'Container Stores';
    String message = 'Hello $name, we have received your payment of GHS ${amountPaid.toStringAsFixed(2)} for invoice $invoiceId at $shopName.';
    if (remainingBalance > 0.01) {
      message += ' Your remaining balance is GHS ${remainingBalance.toStringAsFixed(2)}.';
    } else {
      message += ' Your balance has been fully cleared. Thank you!';
    }
    return await _sendSms(phone, message);
  }

  static Future<bool> sendGeneralSms({
    required String phone,
    required String message,
    String? customSenderId,
  }) async {
    if (phone.trim().isEmpty) return false;
    return await _sendSms(phone.trim(), message, customSenderId: customSenderId);
  }

  static Future<void> sendDispatchSms({
    required String name,
    required String phone,
    required String item,
    required double weight,
    String? location,
  }) async {
    if (phone.isEmpty) return;
    final String locText = location != null && location.isNotEmpty ? ' to be delivered to $location' : '';
    final String message = 'Hello $name, your order for ${weight.toStringAsFixed(1)}kg of $item is ready for dispatch from Container Stores$locText.';
    await _sendSms(phone, message);
  }

  static Future<void> sendTransferNotificationSms({
    required String branchName,
    required String branchCode,
    required String itemDetails,
    required List<UserAccount> branchUsers,
  }) async {
    // SMS Stock alert disabled per user request
  }

  static Future<void> notifyAdmin({required String title, required String message}) async {
    await _sendSms(_adminPhone, '$title: $message');
  }

  static Future<bool> sendSalarySms({
    required String phone,
    required String firstName,
    required double amount,
    required bool isAdvance,
    String? note,
    DateTime? targetMonth,
    bool isUpdate = false,
  }) async {
    if (phone.isEmpty) return false;
    
    final String typeHeader = isUpdate 
        ? 'PAYMENT UPDATE: ' 
        : (isAdvance ? 'ADVANCE PAYMENT ALERT: ' : 'SALARY PAYMENT CONFIRMATION: ');
    
    final String type = isAdvance ? 'an advance' : 'your salary payment';
    final String monthText = targetMonth != null ? ' for ${DateFormat('MMMM yyyy').format(targetMonth)}' : '';
    
    String message = '${typeHeader}Hello $firstName, you have received $type of GHS ${amount.toStringAsFixed(2)}$monthText.';
    
    if (note != null && note.isNotEmpty) {
      message += ' Note: $note';
    }
    message += ' - Container Stores Management';
    return await _sendSms(phone, message);
  }

  static Future<bool> sendWithdrawalSms({
    required String name,
    required double amount,
    required double remaining,
    required String? phone,
    double? totalRemaining,
    String action = 'recorded',
  }) async {
    String message = 'SECURITY ALERT: CEO Withdrawal $action. Amount: GHS ${amount.toStringAsFixed(2)} by $name. Remaining for day: GHS ${remaining.toStringAsFixed(2)}.';
    if (totalRemaining != null) {
      message += ' Total Cash at Shop: GHS ${totalRemaining.toStringAsFixed(2)}.';
    }
    
    // Send to the provided phone number if available, otherwise fallback to admin
    final targetPhone = (phone != null && phone.isNotEmpty) ? phone : _adminPhone;
    return await _sendSms(targetPhone, message);
  }

  static Future<bool> sendDailySummarySms({
    required double dailySales,
    required double tillBalance,
    required List<String> adminPhones,
  }) async {
    final String date = DateFormat('EEE, MMM dd').format(DateTime.now());
    final String message = 'DAILY SUMMARY ($date):\n'
        '• Today\'s Sales: GHS ${dailySales.toStringAsFixed(2)}\n'
        '• Cash at Shop: GHS ${tillBalance.toStringAsFixed(2)}\n\n'
        'Please log in to Close Sales now or tomorrow morning. - Container Stores System';

    bool allSent = true;
    for (final phone in adminPhones) {
      final success = await _sendSms(phone, message);
      if (!success) allSent = false;
    }
    return allSent;
  }

  static Future<bool> sendWeeklySummarySms({
    required DateTime startDate,
    required DateTime endDate,
    required double weeklySales,
    required int totalTransactions,
    required double totalExpenses,
    required double netProfit,
    required Map<String, double> paymentBreakdown,
    required Map<String, double> sectorBreakdown,
    required String topPerformer,
    required int lowStockCount,
    required List<String> adminPhones,
    String? branchName,
  }) async {
    final startStr = DateFormat('MMM dd').format(startDate);
    final endStr = DateFormat('MMM dd').format(endDate);
    final String shopName = branchName ?? 'Container Stores';

    final cash = paymentBreakdown['Cash'] ?? 0.0;
    final momo = paymentBreakdown['Mobile Money'] ?? 0.0;
    final card = paymentBreakdown['Card / Bank'] ?? 0.0;

    final pharm = sectorBreakdown['Pharmacy'] ?? 0.0;
    final barber = sectorBreakdown['Barbershop'] ?? 0.0;
    final tech = sectorBreakdown['Tech & Repairs'] ?? 0.0;
    final retail = sectorBreakdown['Retail / Wholesale'] ?? 0.0;

    String message = 'WEEKLY EXECUTIVE SUMMARY ($startStr - $endStr)\n'
        '$shopName\n'
        '• Sales: GHS ${weeklySales.toStringAsFixed(2)} ($totalTransactions txns)\n'
        '• Expenses: GHS ${totalExpenses.toStringAsFixed(2)}\n'
        '• Net Profit: GHS ${netProfit.toStringAsFixed(2)}\n'
        '• Collections: Cash GHS ${cash.toStringAsFixed(0)} | MoMo GHS ${momo.toStringAsFixed(0)} | Card GHS ${card.toStringAsFixed(0)}\n'
        '• Sectors: Pharm GHS ${pharm.toStringAsFixed(0)} | Barber GHS ${barber.toStringAsFixed(0)} | Tech GHS ${tech.toStringAsFixed(0)} | Retail GHS ${retail.toStringAsFixed(0)}\n'
        '• Top Staff: $topPerformer\n'
        '• Low Stock Alerts: $lowStockCount\n'
        '- Container Multi-Business Engine';

    bool allSent = true;
    for (final phone in adminPhones) {
      final success = await _sendSms(phone, message);
      if (!success) allSent = false;
    }
    return allSent;
  }

  static Future<bool> sendCustomSms(String phone, String message) async {
    if (phone.isEmpty) return false;
    return await _sendSms(phone, message);
  }

  static Future<bool> sendVerificationCodeSms(String phone, String code) async {
    if (phone.isEmpty) return false;
    final String message = 'Your Container Stores password reset code is: $code. Valid for 5 minutes.';
    return await _sendSms(phone, message);
  }

  static Future<bool> sendPasscodeSms(String phone, String name, String passcode) async {
    if (phone.isEmpty) return false;
    final String message = 'Hello $name, your new Container Stores security passcode is: $passcode. Use this to access sensitive system areas.';
    return await _sendSms(phone, message);
  }

  static Future<bool> sendPostHaircutSms({
    required String name,
    required String phone,
    required String serviceName,
    required String barberName,
    String? shopName,
  }) async {
    if (phone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final String message = 'Hello $name, thank you for visiting $store for your $serviceName with $barberName! We hope you love your fresh look. Keep looking sharp & see you next time!';
    return await _sendSms(phone.trim(), message);
  }

  static Future<bool> sendQueueConfirmationSms({
    required String name,
    required String phone,
    required String serviceName,
    required String barberName,
    required int position,
    String? shopName,
    String? queueId,
  }) async {
    if (phone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final String trackLink = queueId != null ? ' Track live: https://container.app/#/track?id=$queueId' : '';
    final String message = 'Hello $name, you have been added to the queue at $store for $serviceName with $barberName. You are #$position in line.$trackLink We\'ll be with you shortly!';
    return await _sendSms(phone.trim(), message);
  }

  static Future<bool> sendKidHaircutSms({
    required String childName,
    required String parentPhone,
    required String serviceName,
    required String barberName,
    String? shopName,
  }) async {
    if (parentPhone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final String message = 'Hello! Your little one $childName just had a fresh $serviceName at $store with $barberName! They look amazing. Thank you for trusting us with your child. See you next time!';
    return await _sendSms(parentPhone.trim(), message);
  }

  static const String defaultBarberMomoNumber = '0552857861';
  static const String defaultBarberMomoName = 'Emmanuel ADU Adjei';

  static String formatMomoInstructions({String? momoNumber, String? momoName}) {
    final num = (momoNumber != null && momoNumber.trim().isNotEmpty) ? momoNumber.trim() : defaultBarberMomoNumber;
    final name = (momoName != null && momoName.trim().isNotEmpty) ? momoName.trim() : defaultBarberMomoName;
    return 'MoMo Number: $num (Name: $name)';
  }

  static Future<bool> sendAppointmentBookingSms({
    required String name,
    required String phone,
    required String serviceName,
    required String barberName,
    required DateTime appointmentTime,
    String? appointmentId,
    String? shopName,
    double? price,
    String? momoNumber,
    String? momoName,
    String? customSenderId,
  }) async {
    if (phone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final dateStr = DateFormat('EEE, d MMM yyyy @ h:mm a').format(appointmentTime);
    final String aptTag = appointmentId != null ? ' (Ref: $appointmentId)' : '';
    final String feeStr = (price != null && price > 0) ? ' Fee: GHS ${price.toStringAsFixed(2)}.' : '';

    // Always ensure the MoMo number and account name are explicitly included
    final String activeMomoNumber = (momoNumber != null && momoNumber.trim().isNotEmpty)
        ? momoNumber.trim()
        : (dotenv.env['BARBER_MOMO_NUMBER']?.trim().isNotEmpty == true
            ? dotenv.env['BARBER_MOMO_NUMBER']!.trim()
            : defaultBarberMomoNumber);

    final String activeMomoName = (momoName != null && momoName.trim().isNotEmpty)
        ? momoName.trim()
        : (dotenv.env['BARBER_MOMO_NAME']?.trim().isNotEmpty == true
            ? dotenv.env['BARBER_MOMO_NAME']!.trim()
            : defaultBarberMomoName);

    final String message = 'Hello $name, your appointment$aptTag for $serviceName with $barberName is scheduled for $dateStr at $store.$feeStr Please make payment to MoMo Number: $activeMomoNumber (Name: $activeMomoName) using your name "$name" as MoMo reference to validate your appointment within 30 mins. Thank you!';
    return await _sendSms(phone.trim(), message, customSenderId: customSenderId);
  }

  static Future<bool> sendAppointmentValidatedSms({
    required String name,
    required String phone,
    required String serviceName,
    required String barberName,
    required DateTime appointmentTime,
    String? appointmentId,
    String? shopName,
    String? customSenderId,
  }) async {
    if (phone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final dateStr = DateFormat('EEE, d MMM yyyy @ h:mm a').format(appointmentTime);
    final String aptTag = appointmentId != null ? ' (Ref: $appointmentId)' : '';
    final String message = 'Hello $name, your appointment$aptTag for $serviceName with $barberName on $dateStr at $store has been VALIDATED and confirmed! Payment received. See you then!';
    return await _sendSms(phone.trim(), message, customSenderId: customSenderId);
  }

  static Future<bool> sendAppointmentReminder30MinSms({
    required String name,
    required String phone,
    required String serviceName,
    required String barberName,
    required DateTime appointmentTime,
    String? shopName,
    String? queueId,
    String? customSenderId,
  }) async {
    if (phone.trim().isEmpty) return false;
    final String store = shopName ?? 'Container Barbershop';
    final timeStr = DateFormat('h:mm a').format(appointmentTime);
    final String queueTag = queueId != null ? ' (Queue ID: $queueId)' : '';
    final String message = 'APPOINTMENT ALERT: Hello $name, your appointment for $serviceName with $barberName is in 30 minutes ($timeStr)! You have been placed in the priority live queue$queueTag at $store. Please head in shortly.';
    return await _sendSms(phone.trim(), message, customSenderId: customSenderId);
  }
}


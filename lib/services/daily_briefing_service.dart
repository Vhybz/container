import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_model.dart';
import '../models/user_model.dart';
import '../models/expense_model.dart';
import 'sale_provider.dart';
import 'product_service.dart';
import 'user_provider.dart';
import 'expense_provider.dart';

class DailyBriefingService {
  /// Compiles today's operations into a formatted WhatsApp briefing message
  static String generateBriefingText({
    required List<SaleRecord> allSales,
    required List<ExpenseRecord> allExpenses,
    required List<UserAccount> allUsers,
    required dynamic productsAsyncValue,
    DateTime? targetDate,
    String? branchName,
  }) {
    final date = targetDate ?? DateTime.now();
    final dateFormatted = DateFormat('EEE, dd MMM yyyy').format(date);
    final timeFormatted = DateFormat('hh:mm a').format(DateTime.now());

    // Filter sales for target date
    final todaySales = allSales.where((s) {
      return s.timestamp.year == date.year &&
          s.timestamp.month == date.month &&
          s.timestamp.day == date.day;
    }).toList();

    // Financial totals
    final double totalRevenue = todaySales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final int transactionCount = todaySales.length;

    // Payment methods
    double cashTotal = 0.0;
    double momoTotal = 0.0;
    double cardTotal = 0.0;

    for (final sale in todaySales) {
      for (final p in sale.payments) {
        if (p.method == PaymentMethod.cash) {
          cashTotal += p.amount;
        } else if (p.method == PaymentMethod.mobileMoney) {
          momoTotal += p.amount;
        } else {
          cardTotal += p.amount;
        }
      }
    }

    // Sector breakdowns
    double pharmacyRevenue = 0.0;
    double barberRevenue = 0.0;
    double techRevenue = 0.0;
    double retailRevenue = 0.0;

    for (final sale in todaySales) {
      for (final item in sale.items) {
        final cat = item.product.category.toUpperCase();
        final name = item.product.name.toUpperCase();
        final itemTotal = item.total;

        if (cat.contains('PHARM') || cat.contains('MED') || cat.contains('DRUG')) {
          pharmacyRevenue += itemTotal;
        } else if (cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM')) {
          barberRevenue += itemTotal;
        } else if (cat.contains('PHONE') || cat.contains('TECH') || cat.contains('REPAIR') || name.contains('IPHONE')) {
          techRevenue += itemTotal;
        } else {
          retailRevenue += itemTotal;
        }
      }
    }

    // Expenses for today
    final todayExpenses = allExpenses.where((e) {
      return e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day;
    }).toList();
    final double totalExpenses = todayExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Net Cash in Drawer to Bank
    final double netCashToBank = cashTotal - totalExpenses;

    // Staff / Barber Performance
    final Map<String, double> staffRevenueMap = {};
    final Map<String, int> staffSalesCountMap = {};

    for (final sale in todaySales) {
      final cashier = sale.cashierName.trim();
      staffRevenueMap[cashier] = (staffRevenueMap[cashier] ?? 0.0) + sale.totalAmount;
      staffSalesCountMap[cashier] = (staffSalesCountMap[cashier] ?? 0) + 1;
    }

    String topPerformerText = 'None';
    if (staffRevenueMap.isNotEmpty) {
      final topEntry = staffRevenueMap.entries.reduce((a, b) => a.value > b.value ? a : b);
      topPerformerText = '${topEntry.key} (GHS ${topEntry.value.toStringAsFixed(2)})';
    }

    // Expiring Drugs & Low Stock
    int expiringSoonCount = 0;
    int lowStockCount = 0;
    if (productsAsyncValue is List) {
      final now = DateTime.now();
      for (final p in productsAsyncValue) {
        if (p.batchExpiryDate != null) {
          final daysLeft = p.batchExpiryDate!.difference(now).inDays;
          if (daysLeft >= 0 && daysLeft <= 30) {
            expiringSoonCount++;
          }
        }
        if (!p.isUnlimited && p.stockQuantity <= p.lowStockThreshold) {
          lowStockCount++;
        }
      }
    }

    final branchHeader = branchName != null && branchName.isNotEmpty ? '[$branchName]' : '[MAIN STORE]';

    return '''
*CONTAINER STORE - EXECUTIVE DAILY CLOSE*
$branchHeader
📅 *Date:* $dateFormatted
⏰ *Generated:* $timeFormatted

━━━━━━━━━━━━━━━━━━━━
💰 *FINANCIAL SUMMARY*
• *Total Revenue:* GHS ${totalRevenue.toStringAsFixed(2)}
• *Transactions:* $transactionCount
• *Total Expenses:* GHS ${totalExpenses.toStringAsFixed(2)}
• *Estimated Net Cash to Bank:* GHS ${netCashToBank.toStringAsFixed(2)}

💳 *COLLECTIONS BREAKDOWN*
• Cash: GHS ${cashTotal.toStringAsFixed(2)}
• Mobile Money: GHS ${momoTotal.toStringAsFixed(2)}
• Card / Bank: GHS ${cardTotal.toStringAsFixed(2)}

🏪 *SECTOR PERFORMANCE*
• 💊 Pharmacy: GHS ${pharmacyRevenue.toStringAsFixed(2)}
• ✂️ Barbershop: GHS ${barberRevenue.toStringAsFixed(2)}
• 📱 Tech & Repairs: GHS ${techRevenue.toStringAsFixed(2)}
• 🛒 Retail / Wholesale: GHS ${retailRevenue.toStringAsFixed(2)}

⭐ *TOP PERFORMER TODAY*
• $topPerformerText

⚠️ *OPERATIONAL ALERTS*
• Low Stock Items: $lowStockCount
• Drugs Expiring in <=30 Days: $expiringSoonCount
━━━━━━━━━━━━━━━━━━━━
_System Generated via Container Multi-Business Engine_
'''.trim();
  }

  /// Launch WhatsApp with pre-filled message
  static Future<bool> openWhatsApp({required String phone, required String message}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '233${cleanPhone.substring(1)}';
    }

    final Uri url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
      return false;
    }
  }

  /// Display interactive preview dialog to review and send daily close to WhatsApp
  static void showBriefingModal(BuildContext context, WidgetRef ref) {
    final sales = ref.read(saleHistoryProvider);
    final expenses = ref.read(expenseProvider);
    final users = ref.read(userProvider);
    final products = ref.read(productsFutureProvider).value;
    final currentUser = ref.read(currentUserProvider);

    final String briefingText = generateBriefingText(
      allSales: sales,
      allExpenses: expenses.records,
      allUsers: users,
      productsAsyncValue: products,
      branchName: currentUser?.branchCode ?? 'MAIN',
    );

    final phoneController = TextEditingController(text: currentUser?.phone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF25D366),
              radius: 16,
              child: Icon(Icons.chat, color: Colors.white, size: 18),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text('Executive Daily Close Briefing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Recipient WhatsApp Number',
                    hintText: 'e.g. 0244123456',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    briefingText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            icon: const Icon(Icons.send),
            label: const Text('SEND TO WHATSAPP'),
            onPressed: () {
              if (phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter recipient phone number.')),
                );
                return;
              }
              Navigator.pop(ctx);
              openWhatsApp(phone: phoneController.text.trim(), message: briefingText);
            },
          ),
        ],
      ),
    );
  }
}

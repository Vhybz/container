import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'sale_provider.dart';
import 'expense_provider.dart';
import 'user_provider.dart';
import 'product_service.dart';
import 'sms_service.dart';
import 'branch_provider.dart';
import '../models/user_model.dart';
import '../models/sale_model.dart';

final weeklyReminderServiceProvider = Provider((ref) => WeeklyReminderService(ref));

class WeeklySummaryData {
  final DateTime startDate;
  final DateTime endDate;
  final double weeklySales;
  final int totalTransactions;
  final double totalExpenses;
  final double netProfit;
  final Map<String, double> paymentBreakdown;
  final Map<String, double> sectorBreakdown;
  final String topPerformer;
  final int lowStockCount;

  WeeklySummaryData({
    required this.startDate,
    required this.endDate,
    required this.weeklySales,
    required this.totalTransactions,
    required this.totalExpenses,
    required this.netProfit,
    required this.paymentBreakdown,
    required this.sectorBreakdown,
    required this.topPerformer,
    required this.lowStockCount,
  });
}

class WeeklyReminderService {
  final Ref ref;
  static const String _boxName = 'weekly_reminders';
  static const String _lastKey = 'last_sent_week';

  WeeklyReminderService(this.ref);

  /// Computes weekly metrics for the past 7 days (or custom range)
  WeeklySummaryData computeWeeklyMetrics({DateTime? endDate}) {
    final end = endDate ?? DateTime.now();
    final start = end.subtract(const Duration(days: 7));

    final allSales = ref.read(saleHistoryProvider);
    final allExpenses = ref.read(expenseProvider).records;
    final products = ref.read(productsFutureProvider).value;

    // Filter sales in date range
    final weeklySalesList = allSales.where((s) {
      return s.timestamp.isAfter(start) &&
          s.timestamp.isBefore(end.add(const Duration(seconds: 1))) &&
          s.status != SaleStatus.cancelled &&
          s.status != SaleStatus.reversed;
    }).toList();

    final double weeklySalesTotal = weeklySalesList.fold(0.0, (sum, s) => sum + s.totalAmount);
    final int transactionCount = weeklySalesList.length;

    // Filter expenses in date range
    final weeklyExpensesList = allExpenses.where((e) {
      return e.date.isAfter(start) && e.date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    final double weeklyExpensesTotal = weeklyExpensesList.fold(0.0, (sum, e) => sum + e.amount);
    final double netProfit = weeklySalesTotal - weeklyExpensesTotal;

    // Payment methods breakdown
    double cashTotal = 0.0;
    double momoTotal = 0.0;
    double cardTotal = 0.0;

    for (final sale in weeklySalesList) {
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

    final paymentBreakdown = {
      'Cash': cashTotal,
      'Mobile Money': momoTotal,
      'Card / Bank': cardTotal,
    };

    // Sector breakdown
    double pharmacyRevenue = 0.0;
    double barberRevenue = 0.0;
    double techRevenue = 0.0;
    double retailRevenue = 0.0;

    for (final sale in weeklySalesList) {
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

    final sectorBreakdown = {
      'Pharmacy': pharmacyRevenue,
      'Barbershop': barberRevenue,
      'Tech & Repairs': techRevenue,
      'Retail / Wholesale': retailRevenue,
    };

    // Staff performance
    final Map<String, double> staffRevenueMap = {};
    for (final sale in weeklySalesList) {
      final cashier = sale.cashierName.trim();
      if (cashier.isNotEmpty) {
        staffRevenueMap[cashier] = (staffRevenueMap[cashier] ?? 0.0) + sale.totalAmount;
      }
    }

    String topPerformerText = 'None';
    if (staffRevenueMap.isNotEmpty) {
      final topEntry = staffRevenueMap.entries.reduce((a, b) => a.value > b.value ? a : b);
      topPerformerText = '${topEntry.key} (GHS ${topEntry.value.toStringAsFixed(0)})';
    }

    // Low stock count
    int lowStockCount = 0;
    if (products != null) {
      for (final p in products) {
        if (!p.isUnlimited && p.stockQuantity <= p.lowStockThreshold) {
          lowStockCount++;
        }
      }
    }

    return WeeklySummaryData(
      startDate: start,
      endDate: end,
      weeklySales: weeklySalesTotal,
      totalTransactions: transactionCount,
      totalExpenses: weeklyExpensesTotal,
      netProfit: netProfit,
      paymentBreakdown: paymentBreakdown,
      sectorBreakdown: sectorBreakdown,
      topPerformer: topPerformerText,
      lowStockCount: lowStockCount,
    );
  }

  /// Automatic trigger check: runs e.g. on Sundays after 8:00 PM (20:00)
  Future<void> checkAndSendWeeklySummary() async {
    try {
      final now = DateTime.now();

      // 1. Send on Sunday (weekday 7) after 8:00 PM (20:00)
      if (now.weekday != DateTime.sunday) return;
      if (now.hour < 20) return;

      // 2. Check if already sent for this calendar week
      final box = await Hive.openBox(_boxName);
      final weekKey = '${now.year}-W${_getWeekNumber(now)}';
      final lastSentWeek = box.get(_lastKey);

      if (lastSentWeek == weekKey) {
        debugPrint('Weekly Reminder: Already sent for week $weekKey.');
        return;
      }

      final summary = computeWeeklyMetrics(endDate: now);

      if (summary.weeklySales <= 0 && summary.totalTransactions == 0) {
        debugPrint('Weekly Reminder: No sales this week. Skipping SMS.');
        return;
      }

      final users = ref.read(userProvider);
      final adminPhones = users
          .where((u) =>
              (u.role == UserRole.admin || u.role == UserRole.superAdmin) &&
              u.phone != null &&
              u.phone!.isNotEmpty)
          .map((u) => u.phone!)
          .toSet()
          .toList();

      if (adminPhones.isEmpty) {
        debugPrint('Weekly Reminder: No admin phone numbers found.');
        return;
      }

      debugPrint('Weekly Reminder: Sending weekly summary SMS to ${adminPhones.length} admins...');
      final success = await SmsService.sendWeeklySummarySms(
        startDate: summary.startDate,
        endDate: summary.endDate,
        weeklySales: summary.weeklySales,
        totalTransactions: summary.totalTransactions,
        totalExpenses: summary.totalExpenses,
        netProfit: summary.netProfit,
        paymentBreakdown: summary.paymentBreakdown,
        sectorBreakdown: summary.sectorBreakdown,
        topPerformer: summary.topPerformer,
        lowStockCount: summary.lowStockCount,
        adminPhones: adminPhones,
      );

      if (success) {
        await box.put(_lastKey, weekKey);
        debugPrint('Weekly Reminder: Sent and recorded for week $weekKey.');
      }
    } catch (e) {
      debugPrint('Weekly Reminder Error: $e');
    }
  }

  /// Manual trigger to dispatch weekly summary SMS on demand
  Future<bool> sendWeeklySummaryNow({List<String>? customAdminPhones, String? branchName}) async {
    final now = DateTime.now();
    final summary = computeWeeklyMetrics(endDate: now);

    final users = ref.read(userProvider);
    final adminPhones = customAdminPhones ??
        users
            .where((u) =>
                (u.role == UserRole.admin || u.role == UserRole.superAdmin) &&
                u.phone != null &&
                u.phone!.isNotEmpty)
            .map((u) => u.phone!)
            .toSet()
            .toList();

    if (adminPhones.isEmpty) {
      debugPrint('sendWeeklySummaryNow: No admin phone numbers found.');
      return false;
    }

    return await SmsService.sendWeeklySummarySms(
      startDate: summary.startDate,
      endDate: summary.endDate,
      weeklySales: summary.weeklySales,
      totalTransactions: summary.totalTransactions,
      totalExpenses: summary.totalExpenses,
      netProfit: summary.netProfit,
      paymentBreakdown: summary.paymentBreakdown,
      sectorBreakdown: summary.sectorBreakdown,
      topPerformer: summary.topPerformer,
      lowStockCount: summary.lowStockCount,
      adminPhones: adminPhones,
      branchName: branchName,
    );
  }

  /// Displays interactive preview dialog to review and send Weekly Executive Summary SMS
  static void showWeeklySmsModal(BuildContext context, WidgetRef ref) {
    final weeklyService = ref.read(weeklyReminderServiceProvider);
    final summary = weeklyService.computeWeeklyMetrics();
    final users = ref.read(userProvider);
    final currentBranch = ref.read(currentBranchProvider);

    final adminUsers = users.where((u) =>
      (u.role == UserRole.admin || u.role == UserRole.superAdmin) &&
      u.phone != null &&
      u.phone!.isNotEmpty
    ).toList();

    final adminPhones = adminUsers.map((u) => u.phone!).toSet().toList();

    final startStr = DateFormat('EEE, d MMM').format(summary.startDate);
    final endStr = DateFormat('EEE, d MMM yyyy').format(summary.endDate);
    final branchName = currentBranch?.name ?? 'Container Stores';

    final cash = summary.paymentBreakdown['Cash'] ?? 0.0;
    final momo = summary.paymentBreakdown['Mobile Money'] ?? 0.0;
    final card = summary.paymentBreakdown['Card / Bank'] ?? 0.0;

    final pharm = summary.sectorBreakdown['Pharmacy'] ?? 0.0;
    final barber = summary.sectorBreakdown['Barbershop'] ?? 0.0;
    final tech = summary.sectorBreakdown['Tech & Repairs'] ?? 0.0;
    final retail = summary.sectorBreakdown['Retail / Wholesale'] ?? 0.0;

    final String smsPreview = '''
WEEKLY EXECUTIVE SUMMARY ($startStr - $endStr)
$branchName
• Revenue: GHS ${summary.weeklySales.toStringAsFixed(2)} (${summary.totalTransactions} sales)
• Expenses: GHS ${summary.totalExpenses.toStringAsFixed(2)}
• Net Profit: GHS ${summary.netProfit.toStringAsFixed(2)}
• Collections: Cash GHS ${cash.toStringAsFixed(0)} | MoMo GHS ${momo.toStringAsFixed(0)} | Card GHS ${card.toStringAsFixed(0)}
• Sectors: Pharm GHS ${pharm.toStringAsFixed(0)} | Barber GHS ${barber.toStringAsFixed(0)} | Tech GHS ${tech.toStringAsFixed(0)} | Retail GHS ${retail.toStringAsFixed(0)}
• Top Staff: ${summary.topPerformer}
• Low Stock Alerts: ${summary.lowStockCount}
- Container Multi-Business Engine
'''.trim();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFF1565C0),
                    radius: 16,
                    child: Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Weekly Executive SMS Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      Text('Recipient Admins (${adminPhones.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(adminPhones.isEmpty ? 'No admin phone numbers configured.' : adminPhones.join(', '), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      const SizedBox(height: 12),
                      const Text('SMS Preview:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          smsPreview,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  icon: isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(isSending ? 'Sending...' : 'SEND WEEKLY SMS NOW'),
                  onPressed: isSending || adminPhones.isEmpty ? null : () async {
                    setState(() => isSending = true);
                    final success = await weeklyService.sendWeeklySummaryNow(
                      customAdminPhones: adminPhones,
                      branchName: branchName,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Weekly Summary SMS dispatched to ${adminPhones.length} admins!' : 'Failed to send SMS. Please check API key or network.'),
                          backgroundColor: success ? Colors.teal : Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../services/sale_provider.dart';
import '../../services/daily_briefing_service.dart';
import '../../models/sale_model.dart';
import '../../widgets/main_app_bar.dart';

class PrescriptionRefillManagerScreen extends ConsumerStatefulWidget {
  const PrescriptionRefillManagerScreen({super.key});

  @override
  ConsumerState<PrescriptionRefillManagerScreen> createState() => _PrescriptionRefillManagerScreenState();
}

class _PrescriptionRefillManagerScreenState extends ConsumerState<PrescriptionRefillManagerScreen> {
  String _filter = 'All'; // 'All', 'Due Soon', 'Overdue'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSales = ref.watch(saleHistoryProvider);

    // Filter sales with prescriptions
    final rxSales = allSales.where((s) {
      return s.prescription != null && s.prescription!.trim().isNotEmpty;
    }).toList();

    // Sort by timestamp descending
    rxSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final now = DateTime.now();

    // Compute refill dates
    final List<Map<String, dynamic>> refillItems = rxSales.map((sale) {
      final daysSupply = _estimateDaysSupply(sale.prescription!);
      final dueDate = sale.timestamp.add(Duration(days: daysSupply));
      final daysDiff = dueDate.difference(now).inDays;

      String status = 'Active';
      Color statusColor = Colors.green;
      if (daysDiff < 0) {
        status = 'Overdue by ${daysDiff.abs()}d';
        statusColor = Colors.red;
      } else if (daysDiff <= 3) {
        status = 'Due in ${daysDiff == 0 ? "today" : "$daysDiff days"}';
        statusColor = Colors.orange;
      } else {
        status = 'Due in $daysDiff days';
        statusColor = Colors.green;
      }

      return {
        'sale': sale,
        'daysSupply': daysSupply,
        'dueDate': dueDate,
        'daysDiff': daysDiff,
        'status': status,
        'statusColor': statusColor,
      };
    }).toList();

    final filtered = refillItems.where((item) {
      final daysDiff = item['daysDiff'] as int;
      if (_filter == 'Due Soon') {
        return daysDiff >= 0 && daysDiff <= 4;
      } else if (_filter == 'Overdue') {
        return daysDiff < 0;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: const MainAppBar(title: 'Prescription Refill Manager'),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Filter Chips & Metric Bar
            Row(
              children: [
                _buildFilterChip('All (${refillItems.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Due Soon (${refillItems.where((i) => (i['daysDiff'] as int) >= 0 && (i['daysDiff'] as int) <= 4).length})', 'Due Soon'),
                const SizedBox(width: 8),
                _buildFilterChip('Overdue (${refillItems.where((i) => (i['daysDiff'] as int) < 0).length})', 'Overdue'),
              ],
            ),
            const SizedBox(height: AppSpacing.m),

            // List of Prescriptions
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medication_liquid_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No prescription refill records found.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final SaleRecord sale = item['sale'];
                        final String patient = sale.patientName?.trim().isNotEmpty == true
                            ? sale.patientName!
                            : (sale.customerName?.trim().isNotEmpty == true ? sale.customerName! : 'Patient');
                        final String phone = sale.customerPhone ?? '';
                        final String status = item['status'];
                        final Color statusColor = item['statusColor'];
                        final DateTime dueDate = item['dueDate'];

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Color(0xFFE0F2F1),
                                          child: Icon(Icons.medication, color: Color(0xFF00695C), size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(patient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Rx: ${sale.prescription}',
                                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.3),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Dispensed: ${DateFormat('dd MMM yyyy').format(sale.timestamp)} • Refill Due: ${DateFormat('dd MMM yyyy').format(dueDate)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.chat, size: 14),
                                      label: const Text('Send WhatsApp Reminder', style: TextStyle(fontSize: 11)),
                                      onPressed: phone.isEmpty
                                          ? null
                                          : () => _sendRefillReminder(patient, phone, sale.prescription!),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
    );
  }

  int _estimateDaysSupply(String prescription) {
    final p = prescription.toLowerCase();
    if (p.contains('30 day') || p.contains('1 month') || p.contains('monthly')) return 30;
    if (p.contains('14 day') || p.contains('2 week')) return 14;
    if (p.contains('10 day')) return 10;
    if (p.contains('7 day') || p.contains('1 week')) return 7;
    if (p.contains('5 day')) return 5;
    if (p.contains('3 day')) return 3;
    return 14; // Standard 2-week default supply
  }

  void _sendRefillReminder(String patient, String phone, String prescription) {
    final message = '''
*CONTAINER PHARMACY - MEDICATION CHECK-IN*
Hello $patient,

This is Container Pharmacy checking in on your health.
Your prescription for *$prescription* is nearing completion.

🏥 To ensure uninterrupted treatment and wellness, we can have your refill pre-packaged and ready for pickup or delivery.

_Reply to this message to reserve your refill or visit us today!_
'''.trim();

    DailyBriefingService.openWhatsApp(phone: phone, message: message);
  }
}

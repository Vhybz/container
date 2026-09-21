import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/barber_records_provider.dart';
import '../services/salary_provider.dart';
import '../services/expense_provider.dart';
import '../models/salary_model.dart';
import '../models/expense_model.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../services/receipt_service.dart';

class BarberSettlementDialog {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required String barberName,
    String? barberPhone,
    String initialFilter = 'Today',
  }) {
    String selectedFilter = initialFilter;
    final deductionsController = TextEditingController(text: '0.00');
    final phoneController = TextEditingController(text: barberPhone ?? '');
    final notesController = TextEditingController();
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final summary = ref.read(barberRecordsProvider.notifier).getBarberCommissionSummary(
            barberName,
            dateFilter: selectedFilter,
          );

          final double deductions = double.tryParse(deductionsController.text.trim()) ?? 0.0;
          final double basePayout = summary.totalCommission + summary.totalTips;
          final double netPayout = (basePayout - deductions).clamp(0.0, double.infinity);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 520,
              constraints: const BoxConstraints(maxHeight: 740),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF1565C0), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settle Barber Commission: $barberName',
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Instant commission settlement & official pay slip generation',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Period Selection Filter
                  const Text('Settlement Period:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ['Today', 'Yesterday', 'This Week', 'This Month'].map((period) {
                      final isSelected = selectedFilter == period;
                      return ChoiceChip(
                        label: Text(period, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (_) {
                          setDialogState(() => selectedFilter = period);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Performance Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _buildMetricRow('Completed Services', '${summary.totalServices} cuts/treatments', isBold: true),
                                _buildMetricRow('Gross Billed Revenue', '₵ ${summary.grossSales.toStringAsFixed(2)}'),
                                const Divider(height: 10),
                                _buildMetricRow('Accrued Commission', '₵ ${summary.totalCommission.toStringAsFixed(2)}', color: Colors.green.shade800, isBold: true),
                                if (summary.totalTips > 0)
                                  _buildMetricRow('Tips Collected', '+₵ ${summary.totalTips.toStringAsFixed(2)}', color: Colors.amber.shade900),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Deductions / Advance Input
                          TextField(
                            controller: deductionsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Deductions / Advances Taken (₵)',
                              prefixText: '₵ ',
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Net Payable Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade700, width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NET PAYABLE COMMISSION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                    const Text('Commission + Tips - Deductions', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                Text(
                                  '₵ ${netPayout.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Payment Method Selector
                          const Text('Disbursement Mode:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Row(
                            children: ['Cash', 'Mobile Money', 'Bank Transfer'].map((mode) {
                              final isSelected = paymentMethod == mode;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: ChoiceChip(
                                    label: Text(mode, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF1565C0),
                                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                                    onSelected: (_) => setDialogState(() => paymentMethod = mode),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),

                          // Barber Phone (for WhatsApp)
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: "Barber WhatsApp Phone Number",
                              hintText: 'e.g. 0244123456',
                              prefixIcon: const Icon(Icons.phone_android, color: Colors.green),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Notes
                          TextField(
                            controller: notesController,
                            decoration: InputDecoration(
                              labelText: 'Settlement Notes (Optional)',
                              hintText: 'e.g. Daily shift payout after 6 cuts',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('CONFIRM & DISBURSE', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (netPayout <= 0 && summary.totalServices == 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No commission earnings to settle for this period.')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          final allUsers = ref.read(userProvider);
                          final matchingUser = allUsers.firstWhere(
                            (u) => '${u.firstName} ${u.surname}'.toLowerCase() == barberName.toLowerCase() ||
                                u.firstName.toLowerCase() == barberName.toLowerCase(),
                            orElse: () => UserAccount(
                              id: 'EXTERNAL',
                              firstName: barberName,
                              surname: '',
                              email: '',
                              role: UserRole.barber,
                              status: AccountStatus.approved,
                              createdAt: DateTime.now(),
                            ),
                          );

                          final payoutId = 'PAY-BARBER-${DateTime.now().millisecondsSinceEpoch}';
                          final String userNote = notesController.text.trim().isNotEmpty
                              ? notesController.text.trim()
                              : 'Commission Settlement ($selectedFilter)';

                          // 1. Record in Salary Ledger
                          try {
                            final salaryRecord = SalaryRecord(
                              id: payoutId,
                              userId: matchingUser.id,
                              amount: netPayout,
                              isAdvance: false,
                              date: DateTime.now(),
                              targetMonth: DateTime.now(),
                              note: matchingUser.id == 'EXTERNAL'
                                  ? '{"external_worker":{"name":"$barberName","phone":"${phoneController.text.trim()}"},"user_note":"$userNote"}'
                                  : userNote,
                            );
                            await ref.read(salaryHistoryProvider.notifier).addPayment(salaryRecord);
                          } catch (e) {
                            debugPrint('Salary settlement notice: $e');
                          }

                          // 2. Record in Expense Ledger under Wages
                          try {
                            final expenseRecord = ExpenseRecord(
                              id: 'EXP-COMM-${DateTime.now().millisecondsSinceEpoch}',
                              title: 'Barber Commission: $barberName ($selectedFilter)',
                              amount: netPayout,
                              category: 'Wages',
                              date: DateTime.now(),
                              notes: 'Settled $paymentMethod payout for ${summary.totalServices} services.',
                            );
                            await ref.read(expenseProvider.notifier).addExpense(expenseRecord);
                          } catch (e) {
                            debugPrint('Expense commission notice: $e');
                          }

                          // 3. Show Completion & Payslip Modal
                          if (context.mounted) {
                            _showSettlementSuccessModal(
                              context: context,
                              barberName: barberName,
                              barberPhone: phoneController.text.trim(),
                              period: selectedFilter,
                              totalServices: summary.totalServices,
                              grossSales: summary.grossSales,
                              commissionEarned: summary.totalCommission,
                              tips: summary.totalTips,
                              deductions: deductions,
                              netPayout: netPayout,
                              paymentMethod: paymentMethod,
                              notes: userNote,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildMetricRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  static void _showSettlementSuccessModal({
    required BuildContext context,
    required String barberName,
    required String barberPhone,
    required String period,
    required int totalServices,
    required double grossSales,
    required double commissionEarned,
    required double tips,
    required double deductions,
    required double netPayout,
    required String paymentMethod,
    String? notes,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
              child: Icon(Icons.check, color: Colors.green.shade800, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Commission Settled!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GHS ${netPayout.toStringAsFixed(2)} has been recorded as paid to $barberName via $paymentMethod.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildMetricRow('Stylist', barberName, isBold: true),
                    _buildMetricRow('Services Settled', '$totalServices cuts'),
                    _buildMetricRow('Gross Billed', '₵ ${grossSales.toStringAsFixed(2)}'),
                    _buildMetricRow('Net Payout', '₵ ${netPayout.toStringAsFixed(2)}', isBold: true, color: Colors.green.shade800),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Generate an official pay slip below:',
                style: TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Pay Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => ReceiptService.printBarberCommissionPaySlip(
                        barberName: barberName,
                        barberPhone: barberPhone,
                        period: period,
                        totalServices: totalServices,
                        grossSales: grossSales,
                        commissionEarned: commissionEarned,
                        tips: tips,
                        deductions: deductions,
                        netPayout: netPayout,
                        paymentMethod: paymentMethod,
                        notes: notes,
                        context: context,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat, size: 16, color: Colors.green),
                      label: const Text('WhatsApp Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => ReceiptService.shareBarberCommissionSlipViaWhatsApp(
                        barberName: barberName,
                        barberPhone: barberPhone,
                        period: period,
                        totalServices: totalServices,
                        grossSales: grossSales,
                        commissionEarned: commissionEarned,
                        tips: tips,
                        deductions: deductions,
                        netPayout: netPayout,
                        paymentMethod: paymentMethod,
                        notes: notes,
                        context: context,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/shift_provider.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../services/receipt_service.dart';

class ShiftHandoverDialog {
  /// Open Start Shift modal to enter opening cash float
  static void showStartShiftDialog(BuildContext context, WidgetRef ref) {
    final floatController = TextEditingController(text: '0.00');
    final quickFloats = [0.0, 50.0, 100.0, 200.0, 500.0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_open, color: Color(0xFF1565C0), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Start Cashier Shift', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the initial cash float currently inside the till to begin sales tracking and blind count reconciliation.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: floatController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Opening Cash Float (₵)',
                    prefixText: '₵ ',
                    prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF1565C0)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.blue.shade50.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Quick Select Float:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: quickFloats.map((amt) {
                    final isSelected = double.tryParse(floatController.text.trim()) == amt;
                    return ChoiceChip(
                      label: Text('₵ ${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1565C0),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                      onSelected: (_) {
                        floatController.text = amt.toStringAsFixed(2);
                        setDialogState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final double? floatAmount = double.tryParse(floatController.text.trim());
                if (floatAmount == null || floatAmount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid float amount.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await ref.read(shiftProvider.notifier).startShift(openingFloat: floatAmount);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text('Shift started successfully with GHS ${floatAmount.toStringAsFixed(2)} opening float!'),
                    ),
                  );
                }
              },
              child: const Text('START SHIFT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Open Blind Till Count & End-of-Day Handover modal
  static void showCloseShiftDialog(BuildContext context, WidgetRef ref) {
    final shift = ref.read(shiftProvider);
    if (shift == null) {
      showStartShiftDialog(context, ref);
      return;
    }

    final totals = ref.read(shiftProvider.notifier).computeLiveShiftTotals();
    final double cashSales = totals['cash']!;
    final double momoSales = totals['momo']!;
    final double cardSales = totals['card']!;
    final double totalSales = totals['total']!;
    final double expectedDrawerCash = shift.openingFloat + cashSales;

    final user = ref.read(currentUserProvider);
    final bool isManager = user?.role == UserRole.admin || user?.role == UserRole.superAdmin;

    // Denomination breakdown state
    final Map<int, TextEditingController> noteControllers = {
      200: TextEditingController(),
      100: TextEditingController(),
      50: TextEditingController(),
      20: TextEditingController(),
      10: TextEditingController(),
      5: TextEditingController(),
      2: TextEditingController(),
      1: TextEditingController(),
    };
    final coinsController = TextEditingController();
    final quickTotalController = TextEditingController();
    final notesController = TextEditingController();

    bool isDenominationMode = true;
    bool managerRevealed = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double computedCountedCash = 0.0;
          if (isDenominationMode) {
            noteControllers.forEach((denom, controller) {
              final count = int.tryParse(controller.text.trim()) ?? 0;
              computedCountedCash += count * denom;
            });
            final coins = double.tryParse(coinsController.text.trim()) ?? 0.0;
            computedCountedCash += coins;
          } else {
            computedCountedCash = double.tryParse(quickTotalController.text.trim()) ?? 0.0;
          }

          final double variance = computedCountedCash - expectedDrawerCash;
          Color varianceColor = Colors.green;
          String varianceLabel = 'Balanced (₵0.00)';
          if (variance > 0.01) {
            varianceColor = Colors.blue.shade700;
            varianceLabel = 'Cash Surplus (+₵${variance.toStringAsFixed(2)})';
          } else if (variance < -0.01) {
            varianceColor = Colors.red.shade700;
            varianceLabel = 'Cash Shortage (-₵${variance.abs().toStringAsFixed(2)})';
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 540,
              constraints: const BoxConstraints(maxHeight: 720),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B1111).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.point_of_sale, color: Color(0xFF6B1111), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Blind Till Count & Shift Handover',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Cashier: ${shift.cashierName} • Started: ${DateFormat('hh:mm a').format(shift.startTime)}',
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
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

                  // Blind Count Security Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber.shade900, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Blind Till Audit: Expected cash is concealed until till counting is finished.',
                            style: TextStyle(fontSize: 11.5, color: Colors.black87),
                          ),
                        ),
                        if (isManager && !managerRevealed)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.visibility, size: 14),
                            label: const Text('Reveal (Admin)', style: TextStyle(fontSize: 11)),
                            onPressed: () => setDialogState(() => managerRevealed = true),
                          ),
                      ],
                    ),
                  ),

                  // Manager revealed summary (if toggled)
                  if (managerRevealed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Opening Float', '₵ ${shift.openingFloat.toStringAsFixed(2)}'),
                          _buildSummaryRow('Cash Sales Taken', '₵ ${cashSales.toStringAsFixed(2)}'),
                          _buildSummaryRow('MoMo Sales Taken', '₵ ${momoSales.toStringAsFixed(2)}'),
                          _buildSummaryRow('Card Sales Taken', '₵ ${cardSales.toStringAsFixed(2)}'),
                          _buildSummaryRow('Total Turnover', '₵ ${totalSales.toStringAsFixed(2)}'),
                          const Divider(height: 10),
                          _buildSummaryRow('Expected Physical Cash', '₵ ${expectedDrawerCash.toStringAsFixed(2)}', isBold: true),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Mode Switcher: Denomination Counter vs Quick Total
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDenominationMode ? const Color(0xFF6B1111).withValues(alpha: 0.08) : Colors.transparent,
                            side: BorderSide(
                              color: isDenominationMode ? const Color(0xFF6B1111) : Colors.grey.shade300,
                              width: isDenominationMode ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.calculate_outlined, size: 16, color: isDenominationMode ? const Color(0xFF6B1111) : Colors.grey),
                          label: Text(
                            'Denomination Counter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isDenominationMode ? FontWeight.bold : FontWeight.normal,
                              color: isDenominationMode ? const Color(0xFF6B1111) : Colors.black87,
                            ),
                          ),
                          onPressed: () => setDialogState(() => isDenominationMode = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !isDenominationMode ? const Color(0xFF6B1111).withValues(alpha: 0.08) : Colors.transparent,
                            side: BorderSide(
                              color: !isDenominationMode ? const Color(0xFF6B1111) : Colors.grey.shade300,
                              width: !isDenominationMode ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.edit_note, size: 16, color: !isDenominationMode ? const Color(0xFF6B1111) : Colors.grey),
                          label: Text(
                            'Quick Total Input',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !isDenominationMode ? FontWeight.bold : FontWeight.normal,
                              color: !isDenominationMode ? const Color(0xFF6B1111) : Colors.black87,
                            ),
                          ),
                          onPressed: () => setDialogState(() => isDenominationMode = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isDenominationMode) ...[
                            const Text(
                              'COUNT GHANA CEDIS BANKNOTES & COINS:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1.4),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.2),
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                ...noteControllers.entries.map((entry) {
                                  final denom = entry.key;
                                  final controller = entry.value;
                                  final count = int.tryParse(controller.text.trim()) ?? 0;
                                  final subtotal = count * denom;

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('₵$denom', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text('note', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        child: SizedBox(
                                          height: 34,
                                          child: TextField(
                                            controller: controller,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            onChanged: (_) => setDialogState(() {}),
                                            decoration: InputDecoration(
                                              hintText: 'Qty',
                                              contentPadding: EdgeInsets.zero,
                                              isDense: true,
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          '₵ ${subtotal.toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: subtotal > 0 ? Colors.black87 : Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                // Loose Coins Row
                                TableRow(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6),
                                      child: Text('Coins / Pesewas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: coinsController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          onChanged: (_) => setDialogState(() {}),
                                          decoration: InputDecoration(
                                            hintText: '₵ 0.00',
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(
                                        '₵ ${(double.tryParse(coinsController.text.trim()) ?? 0.0).toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: quickTotalController,
                              autofocus: true,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                              onChanged: (_) => setDialogState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Total Physical Cash Counted in Drawer (₵)',
                                prefixText: '₵ ',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Live Total Counted Banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TOTAL PHYSICAL CASH COUNTED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                                    Text('Includes all notes & coins in drawer', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                                Text(
                                  '₵ ${computedCountedCash.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Discrepancy / Handover Notes
                          TextField(
                            controller: notesController,
                            decoration: InputDecoration(
                              labelText: 'Handover Notes / Discrepancy Reason (Optional)',
                              hintText: 'e.g., Shortage due to loose coins change deficit',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bottom Action Buttons
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
                          backgroundColor: const Color(0xFF6B1111),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('RECONCILE & CLOSE TILL', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (computedCountedCash < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please count cash before submitting handover.')),
                            );
                            return;
                          }

                          // Compile notes with denomination breakdown if counted
                          String formattedNotes = notesController.text.trim();
                          if (isDenominationMode) {
                            final List<String> denomSummary = [];
                            noteControllers.forEach((denom, controller) {
                              final count = int.tryParse(controller.text.trim()) ?? 0;
                              if (count > 0) denomSummary.add('₵$denom×$count');
                            });
                            final coins = double.tryParse(coinsController.text.trim()) ?? 0.0;
                            if (coins > 0) denomSummary.add('Coins:₵${coins.toStringAsFixed(2)}');
                            if (denomSummary.isNotEmpty) {
                              final denomStr = '[Count: ${denomSummary.join(', ')}]';
                              formattedNotes = formattedNotes.isNotEmpty ? '$formattedNotes $denomStr' : denomStr;
                            }
                          }

                          Navigator.pop(ctx);
                          final closed = await ref.read(shiftProvider.notifier).closeShift(
                            actualCashCounted: computedCountedCash,
                            notes: formattedNotes.isNotEmpty ? formattedNotes : null,
                          );

                          if (context.mounted && closed != null) {
                            _showHandoverSlipModal(context, closed, expectedDrawerCash, variance, varianceColor, varianceLabel);
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

  static Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isBold ? Colors.black87 : Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Post-Handover Reconciliation Slip & Action Modal
  static void _showHandoverSlipModal(
    BuildContext context,
    ShiftRecord shift,
    double expectedCash,
    double variance,
    Color varianceColor,
    String varianceLabel,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift Closed & Reconciled', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Audit summary & End-of-Day report generated', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Variance Highlight Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: varianceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: varianceColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      variance.abs() <= 0.01 ? Icons.check_circle : (variance > 0 ? Icons.trending_up : Icons.warning_amber),
                      color: varianceColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CASH VARIANCE AUDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: varianceColor)),
                          Text(varianceLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: varianceColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Breakdown Table
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Shift Reference', shift.id),
                    _buildSummaryRow('Cashier Name', shift.cashierName),
                    _buildSummaryRow('Total Turnover', '₵ ${shift.totalSales.toStringAsFixed(2)}'),
                    _buildSummaryRow('Cash Sales', '₵ ${shift.expectedCashSales.toStringAsFixed(2)}'),
                    _buildSummaryRow('MoMo Sales', '₵ ${shift.momoSales.toStringAsFixed(2)}'),
                    _buildSummaryRow('Card Sales', '₵ ${shift.cardSales.toStringAsFixed(2)}'),
                    const Divider(height: 10),
                    _buildSummaryRow('Opening Float', '₵ ${shift.openingFloat.toStringAsFixed(2)}'),
                    _buildSummaryRow('Expected Drawer Cash', '₵ ${expectedCash.toStringAsFixed(2)}', isBold: true),
                    _buildSummaryRow('Actual Counted Cash', '₵ ${(shift.actualCashCounted ?? 0.0).toStringAsFixed(2)}', isBold: true),
                    if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                      const Divider(height: 10),
                      _buildSummaryRow('Audit Notes', shift.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Actions: Print Slip, WhatsApp Report, Finish
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print Slip', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () => ReceiptService.printShiftHandoverReport(shift, context: context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () => ReceiptService.shareShiftHandoverViaWhatsApp(shift, context: context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B1111),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

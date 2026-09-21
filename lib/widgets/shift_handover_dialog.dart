import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/shift_provider.dart';
import '../models/shift_model.dart';
import '../core/constants.dart';

class ShiftHandoverDialog {
  /// Open Start Shift modal to enter opening cash float
  static void showStartShiftDialog(BuildContext context, WidgetRef ref) {
    final floatController = TextEditingController(text: '0.00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF1565C0),
              radius: 16,
              child: Icon(Icons.lock_open, color: Colors.white, size: 18),
            ),
            SizedBox(width: 10),
            Text('Start Cashier Shift', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the initial cash float currently inside the till/drawer to begin tracking your shift sales and reconciliation.',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: floatController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening Cash Float (₵)',
                prefixText: '₵ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
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
            child: const Text('START SHIFT'),
          ),
        ],
      ),
    );
  }

  /// Open Close Shift / Handover modal to count drawer and compute variance
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
    final double expectedDrawerCash = shift.openingFloat + cashSales;

    final countedCashController = TextEditingController(text: expectedDrawerCash.toStringAsFixed(2));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double? countedCash = double.tryParse(countedCashController.text.trim());
          final double variance = (countedCash ?? 0.0) - expectedDrawerCash;

          Color varianceColor = Colors.green;
          String varianceLabel = 'Balanced (₵0.00)';
          if (variance > 0.01) {
            varianceColor = Colors.blue;
            varianceLabel = 'Cash Surplus (+₵${variance.toStringAsFixed(2)})';
          } else if (variance < -0.01) {
            varianceColor = Colors.red;
            varianceLabel = 'Cash Shortage (-₵${variance.abs().toStringAsFixed(2)})';
          }

          return AlertDialog(
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFF6B1111),
                  radius: 16,
                  child: Icon(Icons.point_of_sale, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Cash Drawer Handover & Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shift Summary Overview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Cashier', shift.cashierName),
                          _buildSummaryRow('Shift Started', DateFormat('hh:mm a').format(shift.startTime)),
                          const Divider(),
                          _buildSummaryRow('Opening Float', '₵ ${shift.openingFloat.toStringAsFixed(2)}'),
                          _buildSummaryRow('Cash Sales Taken', '₵ ${cashSales.toStringAsFixed(2)}'),
                          _buildSummaryRow('MoMo Sales Taken', '₵ ${momoSales.toStringAsFixed(2)}'),
                          _buildSummaryRow('Card Sales Taken', '₵ ${cardSales.toStringAsFixed(2)}'),
                          const Divider(),
                          _buildSummaryRow('Expected Physical Cash', '₵ ${expectedDrawerCash.toStringAsFixed(2)}', isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Actual Counted Cash
                    TextField(
                      controller: countedCashController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Physical Cash Counted in Drawer (₵)',
                        prefixText: '₵ ',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s),

                    // Live Variance Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: varianceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: varianceColor),
                      ),
                      child: Row(
                        children: [
                          Icon(variance == 0 ? Icons.check_circle : (variance > 0 ? Icons.trending_up : Icons.warning), color: varianceColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Variance: $varianceLabel',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: varianceColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Handover Notes
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Handover Notes / Discrepancy Reason (Optional)',
                        hintText: 'e.g., GH₵ 5 shortage due to change deficit',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B1111), foregroundColor: Colors.white),
                icon: const Icon(Icons.lock),
                label: const Text('COMPLETE HANDOVER'),
                onPressed: () async {
                  final double? actual = double.tryParse(countedCashController.text.trim());
                  if (actual == null || actual < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter counted cash amount.')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final closed = await ref.read(shiftProvider.notifier).closeShift(
                    actualCashCounted: actual,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                  );

                  if (context.mounted && closed != null) {
                    _showHandoverSlipModal(context, closed);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isBold ? Colors.black87 : Colors.grey.shade700, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  static void _showHandoverSlipModal(BuildContext context, ShiftRecord shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Shift Successfully Closed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shift ID: ${shift.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Cashier: ${shift.cashierName}', style: const TextStyle(fontSize: 12)),
            Text('Total Sales: GHS ${shift.totalSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
            Text('Counted Cash: GHS ${(shift.actualCashCounted ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
            Text(
              'Variance: GHS ${(shift.cashVariance ?? 0.0).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: (shift.cashVariance ?? 0.0) >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            const Text('The cash drawer handover record has been saved and synced.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

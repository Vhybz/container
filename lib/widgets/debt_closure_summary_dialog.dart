import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale_model.dart';

class DebtPaymentInfo {
  final String customerName;
  final String? customerPhone;
  final String invoiceId;
  final double amountPaid;
  final double remainingBalance;
  final PaymentMethod paymentMethod;
  final DateTime paymentTime;
  final bool isInitialDeposit;

  DebtPaymentInfo({
    required this.customerName,
    this.customerPhone,
    required this.invoiceId,
    required this.amountPaid,
    required this.remainingBalance,
    required this.paymentMethod,
    required this.paymentTime,
    this.isInitialDeposit = false,
  });
}

List<DebtPaymentInfo> getDebtPaymentsForPeriod(List<SaleRecord> sales, DateTime targetDate) {
  final List<DebtPaymentInfo> results = [];
  final targetYear = targetDate.year;
  final targetMonth = targetDate.month;
  final targetDay = targetDate.day;

  for (final sale in sales) {
    if (!sale.isActive) continue;

    final customerName = (sale.customerName != null && sale.customerName!.trim().isNotEmpty)
        ? sale.customerName!.trim()
        : 'Walk-in / Unknown Debtor';

    // 1. Check if sale has multiple payments (debt payments/collections)
    if (sale.payments.length > 1) {
      for (int i = 1; i < sale.payments.length; i++) {
        final p = sale.payments[i];
        bool isForThisDate = false;

        if (p.date != null) {
          if (p.date!.year == targetYear && p.date!.month == targetMonth && p.date!.day == targetDay) {
            isForThisDate = true;
          }
        } else if (p.reference != null && p.reference!.contains('Manual Collection')) {
          final formattedStr = DateFormat('yyMMdd').format(targetDate);
          if (p.reference!.contains(formattedStr)) {
            isForThisDate = true;
          }
        } else {
          // Fallback: Check if sale timestamp matches target day
          if (sale.timestamp.year == targetYear && sale.timestamp.month == targetMonth && sale.timestamp.day == targetDay) {
            isForThisDate = true;
          }
        }

        if (isForThisDate) {
          results.add(DebtPaymentInfo(
            customerName: customerName,
            customerPhone: sale.customerPhone,
            invoiceId: sale.id,
            amountPaid: p.amount,
            remainingBalance: sale.balance,
            paymentMethod: p.method,
            paymentTime: p.date ?? sale.timestamp,
          ));
        }
      }
    } else if (sale.payments.isNotEmpty && (sale.balance > 0.01 || sale.customerName != null)) {
      // 2. Check if a debt sale was created on targetDate with a down payment
      if (sale.timestamp.year == targetYear && sale.timestamp.month == targetMonth && sale.timestamp.day == targetDay) {
        if (sale.payments.first.amount > 0 && sale.balance > 0.01) {
          results.add(DebtPaymentInfo(
            customerName: customerName,
            customerPhone: sale.customerPhone,
            invoiceId: sale.id,
            amountPaid: sale.payments.first.amount,
            remainingBalance: sale.balance,
            paymentMethod: sale.payments.first.method,
            paymentTime: sale.timestamp,
            isInitialDeposit: true,
          ));
        }
      }
    }
  }

  return results;
}

Widget buildDebtPaymentsClosureSection(BuildContext context, List<DebtPaymentInfo> debtPayments, DateTime closureDate) {
  final theme = Theme.of(context);
  final totalDebtCollected = debtPayments.fold(0.0, (sum, p) => sum + p.amountPaid);

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Debt Payments Collected',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₵${totalDebtCollected.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (debtPayments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              'No debt payments recorded for ${DateFormat('MMM dd, yyyy').format(closureDate)}.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          )
        else ...[
          Text(
            '${debtPayments.length} debtor(s) paid during this period:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: debtPayments.length,
                separatorBuilder: (context, index) => const Divider(height: 8, thickness: 0.5),
                itemBuilder: (context, index) {
                  final item = debtPayments[index];
                  final isCleared = item.remainingBalance <= 0.01;
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: isCleared ? Colors.green.shade100 : Colors.blue.shade100,
                        child: Icon(
                          isCleared ? Icons.check_circle : Icons.person_outline,
                          size: 14,
                          color: isCleared ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.customerPhone != null ? "${item.customerPhone} • " : ""}Invoice: ${item.invoiceId}',
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+₵${item.amountPaid.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                          ),
                          Text(
                            isCleared ? 'DEBT CLEARED' : 'Bal: ₵${item.remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isCleared ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

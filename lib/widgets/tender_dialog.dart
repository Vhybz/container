import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants.dart';
import '../core/image_picker_helper.dart';
import '../models/sale_model.dart';
import '../services/expense_provider.dart';

/// Encapsulates the complete result of a checkout tender transaction
class TenderResult {
  final List<PaymentDetail> payments;
  final double totalAmount;
  final double amountTendered;
  final double changeDue;
  final String? receiptUrl;

  const TenderResult({
    required this.payments,
    required this.totalAmount,
    required this.amountTendered,
    required this.changeDue,
    this.receiptUrl,
  });

  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);
}

class TenderDialog extends ConsumerStatefulWidget {
  final double totalAmount;
  final String? customerName;
  final String? customerPhone;
  final Function(TenderResult result) onComplete;

  const TenderDialog({
    super.key,
    required this.totalAmount,
    this.customerName,
    this.customerPhone,
    required this.onComplete,
  });

  /// Static helper to display the modal dialog
  static Future<void> show(
    BuildContext context, {
    required double totalAmount,
    String? customerName,
    String? customerPhone,
    required Function(TenderResult result) onComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TenderDialog(
        totalAmount: totalAmount,
        customerName: customerName,
        customerPhone: customerPhone,
        onComplete: onComplete,
      ),
    );
  }

  @override
  ConsumerState<TenderDialog> createState() => _TenderDialogState();
}

class _TenderDialogState extends ConsumerState<TenderDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<PaymentDetail> _payments = [];
  PaymentMethod _selectedMethod = PaymentMethod.cash;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _momoPhoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _selectedMomoNetwork = 'MTN';
  double _tenderedCash = 0.0;
  String? _receiptUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tenderedCash = widget.totalAmount;
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
    if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty) {
      _momoPhoneController.text = widget.customerPhone!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _momoPhoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _paidSoFar => _payments.fold(0.0, (sum, p) => sum + p.amount);
  double get _balanceDue => (widget.totalAmount - _paidSoFar).clamp(0.0, widget.totalAmount);

  double get _changeDue {
    if (_selectedMethod != PaymentMethod.cash) return 0.0;
    if (_tenderedCash > _balanceDue) {
      return _tenderedCash - _balanceDue;
    }
    return 0.0;
  }

  /// Calculates smart Ghanaian Cedi quick-cash amounts based on balance due
  List<double> _generateQuickCashSuggestions(double balance) {
    if (balance <= 0.01) return [];

    final suggestions = <double>{};
    // 1. Exact amount
    suggestions.add(balance);

    // 2. Round up to nearest 5 if not whole
    if (balance % 5 != 0) {
      final next5 = (balance / 5).ceil() * 5.0;
      if (next5 > balance) suggestions.add(next5);
    }

    // 3. Round up to nearest 10
    if (balance % 10 != 0) {
      final next10 = (balance / 10).ceil() * 10.0;
      if (next10 > balance) suggestions.add(next10);
    }

    // 4. Common Ghana banknotes: 10, 20, 50, 100, 200
    const banknotes = [10.0, 20.0, 50.0, 100.0, 200.0];
    for (final note in banknotes) {
      if (note >= balance) {
        suggestions.add(note);
      }
    }

    final sortedList = suggestions.toList()..sort();
    return sortedList.take(4).toList();
  }

  void _applyQuickCash(double amount) {
    setState(() {
      _tenderedCash = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  void _addCashBanknote(double noteValue) {
    setState(() {
      final current = double.tryParse(_amountController.text) ?? 0.0;
      final newTendered = current + noteValue;
      _tenderedCash = newTendered;
      _amountController.text = newTendered.toStringAsFixed(2);
    });
  }

  void _addCurrentPayment() {
    if (!_formKey.currentState!.validate()) return;

    final entered = double.tryParse(_amountController.text) ?? 0.0;
    if (entered < 0) return;

    setState(() {
      if (_selectedMethod == PaymentMethod.cash) {
        // If cash entered exceeds balance due, record the exact balance due
        // and track the change due separately for auditing
        final paymentToApply = entered > _balanceDue ? _balanceDue : entered;
        if (paymentToApply > 0) {
          _payments.add(PaymentDetail(
            method: PaymentMethod.cash,
            amount: paymentToApply,
            reference: _noteController.text.isEmpty ? null : _noteController.text.trim(),
            isPaystack: false,
          ));
        }
      } else if (_selectedMethod == PaymentMethod.mobileMoney) {
        final paymentToApply = entered > _balanceDue ? _balanceDue : entered;
        final phone = _momoPhoneController.text.trim();
        final refStr = '$_selectedMomoNetwork${phone.isNotEmpty ? " • $phone" : ""}';
        if (paymentToApply > 0) {
          _payments.add(PaymentDetail(
            method: PaymentMethod.mobileMoney,
            amount: paymentToApply,
            reference: refStr,
            isPaystack: false,
          ));
        }
      } else {
        // Bank deposit
        final paymentToApply = entered > _balanceDue ? _balanceDue : entered;
        if (paymentToApply > 0) {
          _payments.add(PaymentDetail(
            method: PaymentMethod.bankDeposit,
            amount: paymentToApply,
            reference: _noteController.text.isEmpty ? null : _noteController.text.trim(),
            isPaystack: false,
          ));
        }
      }

      // Reset fields for remaining balance
      final remaining = _balanceDue;
      _tenderedCash = remaining;
      _amountController.text = remaining > 0 ? remaining.toStringAsFixed(2) : '0.00';
      _noteController.clear();
    });
  }

  /// 1-Tap Auto-Split: Applies current partial cash and pre-populates MoMo for the rest
  void _autoSplitToMoMo(double cashPortion) {
    if (cashPortion <= 0 || cashPortion >= _balanceDue) return;

    final remainingForMoMo = _balanceDue - cashPortion;

    setState(() {
      // 1. Add cash portion
      _payments.add(PaymentDetail(
        method: PaymentMethod.cash,
        amount: cashPortion,
        reference: 'Cash split',
        isPaystack: false,
      ));

      // 2. Switch to MoMo
      _selectedMethod = PaymentMethod.mobileMoney;
      _tenderedCash = remainingForMoMo;
      _amountController.text = remainingForMoMo.toStringAsFixed(2);
    });
  }

  Future<void> _uploadBankReceipt() async {
    final XFile? image = await ImagePickerHelper.pickAndCompressImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ref.read(expenseProvider.notifier).uploadReceipt(
        bytes,
        'bank_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      if (mounted) setState(() => _receiptUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _completeCheckout() {
    // If user hasn't pressed "Apply" yet but entered an amount, apply it now
    if (_payments.isEmpty || _balanceDue > 0.01) {
      final entered = double.tryParse(_amountController.text) ?? 0.0;
      if (entered > 0) {
        final paymentToApply = entered > _balanceDue ? _balanceDue : entered;
        String? refStr;
        if (_selectedMethod == PaymentMethod.mobileMoney) {
          final phone = _momoPhoneController.text.trim();
          refStr = '$_selectedMomoNetwork${phone.isNotEmpty ? " • $phone" : ""}';
        } else if (_noteController.text.trim().isNotEmpty) {
          refStr = _noteController.text.trim();
        }

        _payments.add(PaymentDetail(
          method: _selectedMethod,
          amount: paymentToApply,
          reference: refStr,
          isPaystack: false,
        ));
      }
    }

    final totalPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    final finalTendered = _selectedMethod == PaymentMethod.cash && _tenderedCash > totalPaid 
        ? _tenderedCash 
        : totalPaid;
    final finalChange = _selectedMethod == PaymentMethod.cash && finalTendered > totalPaid 
        ? finalTendered - totalPaid 
        : 0.0;

    final result = TenderResult(
      payments: List.unmodifiable(_payments),
      totalAmount: widget.totalAmount,
      amountTendered: finalTendered,
      changeDue: finalChange,
      receiptUrl: _receiptUrl,
    );

    Navigator.pop(context);
    widget.onComplete(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final balance = _balanceDue;
    final quickCashList = _generateQuickCashSuggestions(balance);
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final isCash = _selectedMethod == PaymentMethod.cash;
    final isMoMo = _selectedMethod == PaymentMethod.mobileMoney;
    final isBank = _selectedMethod == PaymentMethod.bankDeposit;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.m),
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.payments_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COLLECT PAYMENT',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (widget.customerName != null)
                          Text(
                            'Customer: ${widget.customerName!}',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Total & Balance Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL INVOICE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('₵${widget.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('BALANCE DUE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '₵${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: balance > 0.01 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method Tabs
              Row(
                children: [
                  _methodTab(PaymentMethod.cash, 'CASH', Icons.money_rounded, theme),
                  const SizedBox(width: 8),
                  _methodTab(PaymentMethod.mobileMoney, 'MOMO', Icons.phone_android_rounded, theme),
                  const SizedBox(width: 8),
                  _methodTab(PaymentMethod.bankDeposit, 'BANK', Icons.account_balance_rounded, theme),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Cash Chips (Visible when Cash is active)
              if (isCash && quickCashList.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('QUICK CASH TENDER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                    Text('Ghana Cedis (₵)', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quickCashList.map((amt) {
                    final isSelected = (_tenderedCash - amt).abs() < 0.01;
                    final isExact = (amt - balance).abs() < 0.01;
                    return ActionChip(
                      label: Text(
                        isExact ? 'Exact ₵${amt.toStringAsFixed(2)}' : '₵${amt.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isExact ? Colors.green.shade800 : theme.colorScheme.primary),
                        ),
                      ),
                      backgroundColor: isSelected
                          ? (isExact ? Colors.green.shade700 : theme.colorScheme.primary)
                          : (isExact ? Colors.green.withValues(alpha: 0.12) : theme.colorScheme.primary.withValues(alpha: 0.08)),
                      side: BorderSide(
                        color: isSelected 
                            ? Colors.transparent 
                            : (isExact ? Colors.green.shade400 : theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      onPressed: () => _applyQuickCash(amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // Quick Banknotes Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [5.0, 10.0, 20.0, 50.0, 100.0, 200.0].map((note) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: OutlinedButton(
                          onPressed: () => _addCashBanknote(note),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(40, 28),
                            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('+₵${note.toInt()}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // MoMo Network Selector
              if (isMoMo) ...[
                Row(
                  children: [
                    _momoNetworkChip('MTN', Colors.amber.shade800),
                    const SizedBox(width: 8),
                    _momoNetworkChip('Telecel', Colors.red.shade700),
                    const SizedBox(width: 8),
                    _momoNetworkChip('AT', Colors.blue.shade700),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _momoPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'MoMo Number',
                    hintText: '024XXXXXXX (10 digits)',
                    prefixIcon: Icon(Icons.phone_iphone_rounded, size: 18),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                ),
                const SizedBox(height: 14),
              ],

              // Amount Form Field
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _amountController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: isCash ? 'Cash Tendered' : 'Amount to Pay',
                        prefixText: '₵ ',
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        setState(() {
                          final parsed = double.tryParse(val) ?? 0.0;
                          _tenderedCash = parsed;
                        });
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter amount';
                        final val = double.tryParse(v);
                        if (val == null || val < 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // PROMINENT CHANGE DUE BANNER (When Cash > Balance Due)
              if (isCash && _changeDue > 0.005) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: Colors.green.shade600, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.change_circle_outlined, color: Colors.green.shade800, size: 22),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHANGE DUE TO CUSTOMER',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Tendered: ₵${_tenderedCash.toStringAsFixed(2)} • Due: ₵${balance.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '₵${_changeDue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1-TAP AUTO-SPLIT TO MOMO
              if (isCash && enteredAmount > 0.01 && enteredAmount < balance) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _autoSplitToMoMo(enteredAmount),
                    icon: const Icon(Icons.call_split_rounded, size: 16),
                    label: Text(
                      'Split: ₵${enteredAmount.toStringAsFixed(2)} Cash + ₵${(balance - enteredAmount).toStringAsFixed(2)} MoMo',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade800),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],

              // Bank Deposit Slip Upload
              if (isBank) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _uploadBankReceipt,
                    icon: _isUploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_receiptUrl != null ? Icons.check_circle : Icons.add_a_photo, color: _receiptUrl != null ? Colors.green : null),
                    label: Text(_receiptUrl != null ? 'RECEIPT ATTACHED' : 'UPLOAD DEPOSIT SLIP'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _receiptUrl != null ? Colors.green : Colors.purple,
                      side: BorderSide(color: _receiptUrl != null ? Colors.green : Colors.purple),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Add / Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addCurrentPayment,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: Text(
                    isCash ? 'APPLY CASH PAYMENT' : (isMoMo ? 'APPLY MOMO PAYMENT' : 'APPLY BANK PAYMENT'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBank ? Colors.purple : (isMoMo ? Colors.orange.shade800 : AppColors.accentGreen),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Applied Payments Breakdown List
              if (_payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('APPLIED PAYMENTS (${_payments.length})', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                ..._payments.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        p.method == PaymentMethod.cash ? Icons.money : (p.method == PaymentMethod.mobileMoney ? Icons.phone_android : Icons.account_balance),
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.method.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5)),
                            if (p.reference != null)
                              Text(p.reference!, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text('₵${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _payments.remove(p);
                            final rem = _balanceDue;
                            _amountController.text = rem.toStringAsFixed(2);
                            _tenderedCash = rem;
                          });
                        },
                      ),
                    ],
                  ),
                )),
              ],

              const Divider(height: 28),

              // Bottom Actions: Cancel / Complete Sale
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text('CANCEL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _completeCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      ),
                      child: FittedBox(
                        child: Text(
                          _payments.isEmpty && enteredAmount == 0.0
                              ? 'RECORD AS DEBT'
                              : (_changeDue > 0 ? 'COMPLETE (CHANGE ₵${_changeDue.toStringAsFixed(2)})' : 'COMPLETE SALE'),
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
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

  Widget _methodTab(PaymentMethod method, String label, IconData icon, ThemeData theme) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            final remaining = _balanceDue;
            _tenderedCash = remaining;
            _amountController.text = remaining.toStringAsFixed(2);
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.s),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.white : theme.colorScheme.primary, size: 20),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _momoNetworkChip(String network, Color color) {
    final isSelected = _selectedMomoNetwork == network;
    return Expanded(
      child: ChoiceChip(
        label: Center(
          child: Text(
            network,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        showCheckmark: false,
        onSelected: (val) => setState(() => _selectedMomoNetwork = network),
      ),
    );
  }
}

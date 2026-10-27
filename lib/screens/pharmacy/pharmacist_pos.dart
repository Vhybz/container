import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/customer_model.dart';
import '../../models/product.dart';
import '../../models/sale_model.dart';
import '../../models/pharmacy_models.dart';
import '../../services/cart_provider.dart';
import '../../services/customer_provider.dart';
import '../../services/menu_service.dart';
import '../../services/product_service.dart';
import '../../services/receipt_service.dart';
import '../../services/sale_provider.dart';
import '../../services/user_provider.dart';
import '../../services/sms_service.dart';
import '../../services/pharmacy_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/pos_transaction_history_view.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/passcode_guard.dart';
import '../../widgets/category_filter_rail.dart';

class PharmacistPos extends ConsumerStatefulWidget {
  const PharmacistPos({super.key});

  @override
  ConsumerState<PharmacistPos> createState() => _PharmacistPosState();
}

class _PharmacistPosState extends ConsumerState<PharmacistPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _patientPhoneController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _rxNumberController = TextEditingController();
  final TextEditingController _prescriptionController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedSortMode = 'FEFO Expiry';
  String _paymentMethod = 'Cash';
  Customer? _selectedCustomer;
  int _currentTab = 0; // 0 = New Sale, 1 = History
  bool _prescriptionExpanded = false;
  bool _sendPrescriptionSms = true;
  bool _includePrescriptionOnReceipt = true;
  String _selectedDoctor = 'OTC / Self-Prescribed';
  bool _isCustomDoctor = false;
  bool _isProcessingCheckout = false;

  final TextEditingController _activeDosageController = TextEditingController();
  final Map<String, String> _drugDosages = {};
  String? _selectedDrugId;

  void _syncFullPrescriptionText(List<CartItem> cartItems) {
    if (_drugDosages.isEmpty) {
      _prescriptionController.text = '';
      return;
    }
    final lines = <String>[];
    for (final item in cartItems) {
      final dosage = _drugDosages[item.product.id]?.trim();
      if (dosage != null && dosage.isNotEmpty) {
        final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
        lines.add('• ${item.product.name} (x$qtyStr): $dosage');
      }
    }
    _prescriptionController.text = lines.join('\n');
  }

  void _selectAndPrescribeDrug(String drugId, List<CartItem> cartItems) {
    setState(() {
      _prescriptionExpanded = true;
      _selectedDrugId = drugId;
      _activeDosageController.text = _drugDosages[drugId] ?? '';
    });
  }

  void _applyDosageToAllMeds(List<CartItem> cartItems) {
    final dosage = _activeDosageController.text.trim();
    if (dosage.isEmpty) return;
    setState(() {
      for (final item in cartItems) {
        _drugDosages[item.product.id] = dosage;
      }
      _syncFullPrescriptionText(cartItems);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dosage applied to all ${cartItems.length} medications on checkout.'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  void _selectNextDrug(List<CartItem> cartItems) {
    if (cartItems.isEmpty) return;
    int currentIndex = -1;
    if (_selectedDrugId != null && _selectedDrugId != 'ALL') {
      currentIndex = cartItems.indexWhere((ci) => ci.product.id == _selectedDrugId);
    }
    final nextIndex = (currentIndex + 1) % cartItems.length;
    final nextDrug = cartItems[nextIndex];
    setState(() {
      _selectedDrugId = nextDrug.product.id;
      _activeDosageController.text = _drugDosages[nextDrug.product.id] ?? '';
    });
  }

  String _getDrugName(String? id, List<CartItem> cartItems) {
    if (id == null || id == 'ALL') return 'All Medications';
    final item = cartItems.where((ci) => ci.product.id == id).firstOrNull;
    return item != null ? item.product.name : 'Medication';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cartProvider.notifier).registerPos('/pharmacy/pos');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _patientController.dispose();
    _patientPhoneController.dispose();
    _doctorController.dispose();
    _rxNumberController.dispose();
    _prescriptionController.dispose();
    _activeDosageController.dispose();
    super.dispose();
  }

  String _formatUnit(String unit, {double count = 1.0}) {
    final u = unit.trim().toLowerCase();
    if (u.isEmpty || u == 'pcs' || u == 'pc' || u == 'piece' || u == 'pieces') {
      return 'pcs';
    }
    if (u == 'tablet' || u == 'tablets') {
      return count == 1 ? 'tablet' : 'tablets';
    }
    if (u == 'capsule' || u == 'capsules') {
      return count == 1 ? 'capsule' : 'capsules';
    }
    if (u == 'bottle' || u == 'bottles') {
      return count == 1 ? 'bottle' : 'bottles';
    }
    if (u == 'pack' || u == 'packs') {
      return count == 1 ? 'pack' : 'packs';
    }
    if (u == 'box' || u == 'boxes') {
      return count == 1 ? 'box' : 'boxes';
    }
    if (u == 'mil' || u == 'mils' || u == 'ml') {
      return 'ml';
    }
    return u;
  }

  void _addToCart(Product product, bool isWholesale) {
    // Safety Quarantine: Dispensing expired medications is strictly prohibited
    if (product.isExpired) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.dangerous_rounded, color: Colors.red, size: 48),
          title: const Text('Safety Alert: Expired Medication', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product.name} expired on ${DateFormat('dd MMM yyyy').format(product.batchExpiryDate!)}.',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FEFO Safety Protocol: Dispensing expired medications is strictly prohibited. Please immediately quarantine batch "${product.batchNumber ?? "Unknown"}" from the dispensary shelf.',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood / Quarantine Batch', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final pcsPerPack = product.piecesPerPack ?? 1.0;
    final packPrice = product.effectivePackPrice;
    final packsPerBox = product.packsPerBox ?? 10.0;
    final boxPrice = product.boxPrice ?? (packPrice * packsPerBox);
    final hasMultiTier = pcsPerPack > 1 || (packsPerBox > 1 && pcsPerPack > 1);

    double currentQty = 1.0;
    final customQtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double customQty = double.tryParse(customQtyController.text) ?? currentQty;
          final double totalPiecePrice = customQty * product.retailPrice;
          final String unitStr = _formatUnit(product.unit, count: customQty);
          final bool isLowStock = product.stockQuantity <= product.lowStockThreshold && !product.isUnlimited;
          final bool isOutOfStock = product.stockQuantity <= 0 && !product.isUnlimited;

          void updateQty(double newQty) {
            if (newQty < 0.1) return;
            if (!product.isUnlimited && newQty > product.stockQuantity && product.stockQuantity > 0) {
              newQty = product.stockQuantity;
            }
            setDialogState(() {
              currentQty = newQty;
              customQtyController.text = newQty % 1 == 0 ? newQty.toInt().toString() : newQty.toStringAsFixed(1);
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.medication_rounded, color: Color(0xFF047857), size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₵${product.retailPrice.toStringAsFixed(2)} / ${_formatUnit(product.unit, count: 1)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                      ),
                                    ),
                                    if (product.batchExpiryDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: product.isExpiringCritical ? const Color(0xFFFFEDD5) : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: product.isExpiringCritical ? const Color(0xFFFDBA74) : const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Text(
                                          'EXP: ${DateFormat('MM/yy').format(product.batchExpiryDate!)}${product.daysUntilExpiry != null ? ' (${product.daysUntilExpiry}d)' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: product.isExpiringCritical ? const Color(0xFFC2410C) : const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    if (!product.isUnlimited)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isOutOfStock
                                              ? Colors.red.shade50
                                              : (isLowStock ? Colors.amber.shade50 : const Color(0xFFECFDF5)),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isOutOfStock
                                                ? Colors.red.shade200
                                                : (isLowStock ? Colors.amber.shade300 : const Color(0xFFA7F3D0)),
                                          ),
                                        ),
                                        child: Text(
                                          isOutOfStock
                                              ? 'Out of Stock'
                                              : 'Stock: ${product.stockQuantity.toInt()} ${_formatUnit(product.unit, count: product.stockQuantity)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isOutOfStock
                                                ? Colors.red.shade700
                                                : (isLowStock ? Colors.amber.shade900 : const Color(0xFF047857)),
                                          ),
                                        ),
                                      ),
                                    if (product.requiresPrescription)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.purple.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.receipt_long_rounded, size: 12, color: Colors.purple),
                                            const SizedBox(width: 3),
                                            const Text('Rx Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section Title
                      Text(
                        hasMultiTier ? '1. Dispense Individual ${_formatUnit(product.unit, count: 2)}:' : 'Select Quantity to Dispense:',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 10),

                      // Quantity Stepper Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Minus Button
                            Material(
                              color: customQty > 1 ? Colors.white : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              elevation: customQty > 1 ? 1 : 0,
                              child: InkWell(
                                onTap: customQty > 1 ? () => updateQty(customQty - 1) : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 20,
                                    color: customQty > 1 ? const Color(0xFF0F172A) : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                            // Editable Quantity Display
                            Expanded(
                              child: Align(
                                alignment: Alignment.center,
                                child: IntrinsicWidth(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          controller: customQtyController,
                                          textAlign: TextAlign.center,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (v) => setDialogState(() {}),
                                        ),
                                      ),
                                      Text(
                                        unitStr,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Plus Button
                            Material(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(8),
                              elevation: 1,
                              child: InkWell(
                                onTap: () => updateQty(customQty + 1),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Preset Selection Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final preset in [1, 2, 3, 5, 10])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    customQty == preset ? '$preset $unitStr ✓' : '+$preset',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: customQty == preset ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                  backgroundColor: customQty == preset ? const Color(0xFF047857) : const Color(0xFFF1F5F9),
                                  side: BorderSide(
                                    color: customQty == preset ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: () => updateQty(preset.toDouble()),
                                ),
                              ),
                            if (!product.isUnlimited && product.stockQuantity > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(
                                    'Max (${product.stockQuantity.toInt()})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                  ),
                                  backgroundColor: const Color(0xFFECFDF5),
                                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  onPressed: () => updateQty(product.stockQuantity),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Live Calculation Summary Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₵${product.retailPrice.toStringAsFixed(2)} × ${customQty % 1 == 0 ? customQty.toInt() : customQty} $unitStr',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Text(
                              '₵${totalPiecePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Add to Cart Button
                      ElevatedButton.icon(
                        onPressed: isOutOfStock
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _addItemToCart(product, customQty, product.retailPrice);
                              },
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(
                          isOutOfStock ? 'Item Out of Stock' : 'Add $unitStr to Cart (₵${totalPiecePrice.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                      // Multi-Tier Options (Full Pack / Full Box)
                      if (pcsPerPack > 1) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('OR BULK TIERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(ctx);
                              final packProduct = product.copyWith(
                                name: '${product.name} (Pack)',
                                unit: 'pack',
                              );
                              _addItemToCart(packProduct, 1.0, packPrice);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Full Pack', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${pcsPerPack.toInt()} ${_formatUnit(product.unit, count: pcsPerPack)} inside',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text('₵${packPrice.toStringAsFixed(2)} per pack', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      final packProduct = product.copyWith(
                                        name: '${product.name} (Pack)',
                                        unit: 'pack',
                                      );
                                      _addItemToCart(packProduct, 1.0, packPrice);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Add Pack', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (packsPerBox > 1 && pcsPerPack > 1) ...[
                        const SizedBox(height: 10),
                        Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(ctx);
                              final boxProduct = product.copyWith(
                                name: '${product.name} (Box)',
                                unit: 'box',
                              );
                              _addItemToCart(boxProduct, 1.0, boxPrice);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.archive_outlined, color: Colors.indigo, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Full Box', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.indigo.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${packsPerBox.toInt()} packs inside',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text('₵${boxPrice.toStringAsFixed(2)} per box', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      final boxProduct = product.copyWith(
                                        name: '${product.name} (Box)',
                                        unit: 'box',
                                      );
                                      _addItemToCart(boxProduct, 1.0, boxPrice);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Add Box', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addItemToCart(Product product, double qty, double price) {
    ref.read(cartProvider.notifier).addItemWithCustomPrice(product, qty, price, price);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _hasRxRequired(List<CartItem> cart) {
    return cart.any((item) => item.product.requiresPrescription || item.product.category.toUpperCase().contains('PHARMA'));
  }

  void _checkout() async {
    if (_isProcessingCheckout) return;
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    setState(() => _isProcessingCheckout = true);

    try {
      // Ensure prescription text is compiled and synced from dosage inputs before checkout
      _syncFullPrescriptionText(cartItems);
      String prescriptionText = _prescriptionController.text.trim();
      if (prescriptionText.isEmpty && _activeDosageController.text.trim().isNotEmpty) {
        final activeDose = _activeDosageController.text.trim();
        for (final item in cartItems) {
          _drugDosages[item.product.id] = activeDose;
        }
        _syncFullPrescriptionText(cartItems);
        prescriptionText = _prescriptionController.text.trim();
      }

      // If "Send via SMS" is checked and prescription text is still empty, auto-generate cart medication summary
      if (_sendPrescriptionSms && prescriptionText.isEmpty && cartItems.isNotEmpty) {
        final lines = <String>[];
        for (final item in cartItems) {
          final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
          lines.add('• ${item.product.name} (x$qtyStr): Take as directed by pharmacist');
        }
        prescriptionText = lines.join('\n');
      }

      final hasPrescription = prescriptionText.isNotEmpty;
      String patientPhone = _patientPhoneController.text.trim().isNotEmpty 
          ? _patientPhoneController.text.trim() 
          : (_selectedCustomer?.phone.trim() ?? '');

      // If patient phone is empty, offer an optional quick prompt so patient can receive SMS
      if (patientPhone.isEmpty && mounted) {
        final phoneEntered = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final promptPhoneController = TextEditingController();
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.sms_outlined, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  const Text('Send SMS Receipt / Rx?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter patient phone number for free SMS receipt & dosage instructions, or tap Skip.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptPhoneController,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                      LengthLimitingTextInputFormatter(16),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Patient Phone Number',
                      hintText: 'e.g. 0244123456 or +233244123456',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('Skip (No SMS)'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, promptPhoneController.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                  child: const Text('Send SMS'),
                ),
              ],
            );
          },
        );
        if (phoneEntered != null && phoneEntered.trim().isNotEmpty) {
          patientPhone = phoneEntered.trim();
          _patientPhoneController.text = patientPhone;
        }
      }

      final currentUser = ref.read(currentUserProvider);
      final String cashierName = currentUser != null ? '${currentUser.firstName} ${currentUser.surname}' : 'Pharmacist';
      final subtotal = ref.read(cartProvider.notifier).subtotal;

      final saleItems = cartItems.map((item) {
        return SaleItem(
          product: item.product,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
          originalPrice: item.originalPrice,
        );
      }).toList();

      final PaymentMethod mode = _paymentMethod == 'MoMo' 
          ? PaymentMethod.mobileMoney 
          : (_paymentMethod == 'Card' ? PaymentMethod.bankDeposit : PaymentMethod.cash);

      final patientName = _patientController.text.trim().isNotEmpty 
          ? _patientController.text.trim() 
          : (_selectedCustomer?.name ?? 'Walk-In Patient');
      final doctorName = _doctorController.text.trim().isNotEmpty ? _doctorController.text.trim() : null;
      final rxNum = _rxNumberController.text.trim().isNotEmpty ? _rxNumberController.text.trim() : null;

      final sale = SaleRecord(
        id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        branchCode: currentUser?.branchCode ?? 'MAIN',
        items: saleItems,
        totalAmount: subtotal,
        totalDiscount: 0.0,
        totalCost: subtotal * 0.7,
        payments: [PaymentDetail(method: mode, amount: subtotal)],
        timestamp: DateTime.now(),
        cashierName: cashierName,
        cashierId: currentUser?.id ?? 'N/A',
        customerName: _selectedCustomer?.name ?? (patientName != 'Walk-In Patient' ? patientName : null),
        customerPhone: patientPhone.isNotEmpty ? patientPhone : null,
        status: SaleStatus.completed,
        isVerified: true,
        prescription: hasPrescription ? prescriptionText : null,
        includePrescriptionOnReceipt: _includePrescriptionOnReceipt,
        sendPrescriptionSms: _sendPrescriptionSms,
        patientName: patientName,
        doctorName: doctorName,
        rxNumber: rxNum,
      );

      // Save sale to local state
      await ref.read(saleHistoryProvider.notifier).addSale(sale);

      // Record prescription in prescription history provider
      if (hasPrescription) {
        ref.read(prescriptionsProvider.notifier).recordPrescription(
          PrescriptionRecord(
            id: 'RX-${DateTime.now().millisecondsSinceEpoch}',
            rxNumber: rxNum ?? 'RX-${sale.id}',
            patientName: patientName,
            doctorName: doctorName,
            medications: [prescriptionText],
            dispensedAt: DateTime.now(),
            status: 'Dispensed',
          ),
        );
      }

      final pharmacyBranch = currentUser?.branchCode != null ? 'Emmanuel Chemist (${currentUser!.branchCode})' : 'Emmanuel Chemist';

      bool receiptSmsSuccess = false;
      bool rxSmsSuccess = false;

      // Send Prescription SMS Receipt & Clinical Rx SMS in parallel
      if (patientPhone.isNotEmpty) {
        debugPrint('Pharmacy POS: Sending Receipt & Prescription SMS to $patientPhone...');
        final smsResults = await Future.wait([
          SmsService.sendReceiptSms(
            sale,
            branchName: pharmacyBranch,
            customPhone: patientPhone,
          ),
          if (hasPrescription || _sendPrescriptionSms)
            SmsService.sendPrescriptionSms(
              phone: patientPhone,
              patientName: patientName,
              prescription: prescriptionText,
              rxNumber: rxNum,
              doctorName: doctorName,
              pharmacistName: cashierName,
              branchName: pharmacyBranch,
            ),
        ]);
        receiptSmsSuccess = smsResults.isNotEmpty ? smsResults[0] : false;
        if (smsResults.length > 1) {
          rxSmsSuccess = smsResults[1];
        } else {
          rxSmsSuccess = receiptSmsSuccess;
        }
      }

      // Trigger printing receipt
      if (_includePrescriptionOnReceipt || !hasPrescription) {
        try {
          ReceiptService.printReceipt(sale, context: null);
        } catch (e) {
          debugPrint('Pharmacy POS Print Notice: $e');
        }
      }

      // Clean cart and checkout state immediately after sale
      ref.read(cartProvider.notifier).clear();
      setState(() {
        _selectedCustomer = null;
        _patientController.clear();
        _patientPhoneController.clear();
        _doctorController.clear();
        _selectedDoctor = 'OTC / Self-Prescribed';
        _isCustomDoctor = false;
        _rxNumberController.clear();
        _prescriptionController.clear();
        _activeDosageController.clear();
        _drugDosages.clear();
        _selectedDrugId = null;
        _prescriptionExpanded = false;
        _paymentMethod = 'Cash';
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              const Text('Dispense Successful'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice: ${sale.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('Total Paid: ${currencyFormat.format(subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Payment Method: $_paymentMethod'),
                if (hasPrescription) ...[
                  const Divider(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medication_liquid, size: 16, color: Colors.teal),
                            const SizedBox(width: 4),
                            const Text('Prescription Prescribed (Rx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Patient: $patientName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        if (doctorName != null) Text('Doctor: $doctorName', style: const TextStyle(fontSize: 11)),
                        if (rxNum != null) Text('Rx No: $rxNum', style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(prescriptionText, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
                const Divider(),
                if (patientPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (rxSmsSuccess || receiptSmsSuccess) 
                          ? 'SMS Receipt & Prescription sent to $patientPhone.' 
                          : 'SMS Dispatch triggered to $patientPhone.',
                      style: TextStyle(fontSize: 11, color: (rxSmsSuccess || receiptSmsSuccess) ? Colors.teal : Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                const Text('Inventory updated successfully.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            if (hasPrescription && patientPhone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final sent = await SmsService.sendPrescriptionSms(
                    phone: patientPhone,
                    patientName: patientName,
                    prescription: prescriptionText,
                    rxNumber: rxNum,
                    doctorName: doctorName,
                    pharmacistName: cashierName,
                    branchName: pharmacyBranch,
                  );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        backgroundColor: sent ? const Color(0xFF2E7D32) : Colors.red,
                        content: Text(sent ? 'Rx SMS sent to $patientPhone!' : 'Failed to send Rx SMS to $patientPhone. Check API balance or network.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.sms_outlined, size: 18),
                label: const Text('RESEND RX SMS'),
              ),
            OutlinedButton.icon(
              onPressed: () => ReceiptService.printReceipt(sale, context: context),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('PRINT RECEIPT'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
              child: const Text('OK / NEW SALE'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingCheckout = false);
      }
    }
  }

  void _saveAsDebt() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    if (_selectedCustomer == null) {
      await _showCustomerDialog();
      if (_selectedCustomer == null) return;
    }

    _syncFullPrescriptionText(cartItems);
    String prescriptionText = _prescriptionController.text.trim();
    if (prescriptionText.isEmpty && _activeDosageController.text.trim().isNotEmpty) {
      final activeDose = _activeDosageController.text.trim();
      for (final item in cartItems) {
        _drugDosages[item.product.id] = activeDose;
      }
      _syncFullPrescriptionText(cartItems);
      prescriptionText = _prescriptionController.text.trim();
    }

    // If "Send via SMS" is checked and prescription text is still empty, auto-generate cart medication summary
    if (_sendPrescriptionSms && prescriptionText.isEmpty && cartItems.isNotEmpty) {
      final lines = <String>[];
      for (final item in cartItems) {
        final qtyStr = item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString();
        lines.add('• ${item.product.name} (x$qtyStr): Take as directed by pharmacist');
      }
      prescriptionText = lines.join('\n');
    }

    final hasPrescription = prescriptionText.isNotEmpty;
    final patientPhone = _patientPhoneController.text.trim().isNotEmpty 
        ? _patientPhoneController.text.trim() 
        : _selectedCustomer!.phone.trim();
    final patientName = _patientController.text.trim().isNotEmpty 
        ? _patientController.text.trim() 
        : _selectedCustomer!.name;
    final doctorName = _doctorController.text.trim().isNotEmpty ? _doctorController.text.trim() : null;
    final rxNum = _rxNumberController.text.trim().isNotEmpty ? _rxNumberController.text.trim() : null;

    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final currentUser = ref.read(currentUserProvider);
    final debtCustName = _selectedCustomer!.name;

    final saleItems = cartItems.map((item) => SaleItem(
      product: item.product,
      quantity: item.quantity,
      priceAtSale: item.priceAtSale,
      originalPrice: item.originalPrice,
    )).toList();

    final sale = SaleRecord(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      branchCode: currentUser?.branchCode ?? 'MAIN',
      items: saleItems,
      totalAmount: subtotal,
      totalDiscount: 0.0,
      totalCost: subtotal * 0.7,
      payments: [],
      timestamp: DateTime.now(),
      cashierName: currentUser?.name ?? 'Pharmacist',
      cashierId: currentUser?.id ?? 'N/A',
      customerName: _selectedCustomer!.name,
      customerPhone: _selectedCustomer!.phone,
      status: SaleStatus.completed,
      isVerified: true,
      prescription: hasPrescription ? prescriptionText : null,
      includePrescriptionOnReceipt: _includePrescriptionOnReceipt,
      sendPrescriptionSms: _sendPrescriptionSms,
      patientName: patientName,
      doctorName: doctorName,
      rxNumber: rxNum,
    );

    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    // Send Prescription SMS Receipt if phone is provided (before print layout)
    if (patientPhone.isNotEmpty) {
      final pharmacyBranch = currentUser?.branchCode != null ? 'Emmanuel Chemist (${currentUser!.branchCode})' : 'Emmanuel Chemist';
      await SmsService.sendReceiptSms(
        sale,
        branchName: pharmacyBranch,
        customPhone: patientPhone,
      );

      if (hasPrescription || _sendPrescriptionSms) {
        await SmsService.sendPrescriptionSms(
          phone: patientPhone,
          patientName: patientName,
          prescription: prescriptionText,
          rxNumber: rxNum,
          doctorName: doctorName,
          pharmacistName: currentUser?.name ?? 'Pharmacist',
          branchName: pharmacyBranch,
        );
      }
    }

    // Trigger printing receipt after SMS dispatch
    if (_includePrescriptionOnReceipt && hasPrescription) {
      try {
        ReceiptService.printReceipt(sale, context: null);
      } catch (e) {
        debugPrint('Pharmacy POS Debt Print Notice: $e');
      }
    }

    // Record in prescription history provider
    if (hasPrescription) {
      ref.read(prescriptionsProvider.notifier).recordPrescription(
        PrescriptionRecord(
          id: 'RX-${DateTime.now().millisecondsSinceEpoch}',
          rxNumber: rxNum ?? 'RX-${sale.id}',
          patientName: patientName,
          doctorName: doctorName,
          medications: [prescriptionText],
          dispensedAt: DateTime.now(),
          status: 'Dispensed',
        ),
      );
    }

    // Clean cart and checkout state immediately after debt sale
    ref.read(cartProvider.notifier).clear();
    setState(() {
      _selectedCustomer = null;
      _patientController.clear();
      _patientPhoneController.clear();
      _doctorController.clear();
      _selectedDoctor = 'OTC / Self-Prescribed';
      _isCustomDoctor = false;
      _rxNumberController.clear();
      _prescriptionController.clear();
      _activeDosageController.clear();
      _drugDosages.clear();
      _selectedDrugId = null;
      _prescriptionExpanded = false;
      _paymentMethod = 'Cash';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale saved as outstanding debt for $debtCustName')),
    );
  }

  Future<void> _showCustomerDialog() async {
    final searchController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final customers = ref.watch(customerProvider);

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final query = searchController.text.trim().toLowerCase();
              final filtered = customers.where((c) =>
                c.name.toLowerCase().contains(query) || c.phone.contains(query)
              ).toList();

              return AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Customer'),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF2E7D32)),
                      tooltip: 'Register New Customer',
                      onPressed: () => _showAddNewCustomerModal(ctx),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 380,
                  height: 420,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by Name or Phone...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Align(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.person_off_outlined, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text('No customers found', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddNewCustomerModal(ctx),
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('Register New Customer'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  return Column(
                                    children: [
                                      ListTile(
                                        leading: const CircleAvatar(child: Icon(Icons.person)),
                                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text(c.phone),
                                        onTap: () {
                                          setState(() {
                                            _selectedCustomer = c;
                                            _patientController.text = c.name;
                                            _patientPhoneController.text = c.phone;
                                          });
                                          Navigator.pop(ctx);
                                        },
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddNewCustomerModal(BuildContext parentContext) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_add_outlined, color: Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            const Text('Register New Customer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Full Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              final newCust = Customer(
                id: UuidUtils.generate(),
                branchCode: ref.read(currentUserProvider)?.branchCode ?? 'MAIN',
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                phone2: null,
                location: 'POS Auto-Registration',
              );
              ref.read(customerProvider.notifier).addCustomer(newCust);
              setState(() {
                _selectedCustomer = newCust;
                _patientController.text = newCust.name;
                _patientPhoneController.text = newCust.phone;
              });
              Navigator.pop(ctx);
              if (parentContext.mounted) Navigator.pop(parentContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Customer "${newCust.name}" registered and selected!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: const Text('REGISTER & SELECT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (user == null) return Scaffold(body: Align(alignment: Alignment.center, child: CircularProgressIndicator()));

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isWholesale = ref.watch(isWholesaleProvider);
    final menuItems = MenuService.getMenuItemsForUser(user);
    final productsAsync = ref.watch(productsFutureProvider);
    final rawProducts = productsAsync.value ?? [];

    final productsList = rawProducts
        .where((p) => !p.isDeleted)
        .where((p) {
            final cat = p.category.toUpperCase();
            final name = p.name.toUpperCase();

            // 1. Strict Exclusions (No smartphones, tech, repairs, or barber services in Pharmacy POS)
            final isTechOrPhone = p.requiresImei || 
                cat.contains('PHONE') || 
                cat.contains('SMART') || 
                cat.contains('TECH') || 
                cat.contains('DEVICE') || 
                cat.contains('REPAIR') || 
                cat.contains('ACCESSOR') || 
                cat.contains('AUDIO') || 
                cat.contains('CHARGER') || 
                name.contains('IPHONE') || 
                name.contains('SAMSUNG') || 
                name.contains('12 PRO') ||
                name.contains('12 MINI') ||
                name.contains('13 PRO') ||
                name.contains('IPHONE XR') ||
                name.contains('GIG');

            final isBarberStuff = cat.contains('BARBER') || 
                cat.contains('HAIR') || 
                cat.contains('BEARD') || 
                cat.contains('GROOM') || 
                cat.contains('SALON') || 
                name.contains('KIDS 1-') ||
                name.contains('KIDS 10-');

            if (isTechOrPhone || isBarberStuff) return false;

            // All non-tech, non-barber items (including any custom categories created in Stock Control) are included
            return true;
          })
          .toList();

    final List<String> categories = ['All', ...productsList.map((p) => p.category.toUpperCase()).toSet()];

    final Map<String, int> categoryCounts = {
      'All': productsList.length,
    };
    for (final p in productsList) {
      final cat = p.category.toUpperCase();
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    final filteredProducts = productsList.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category.toUpperCase() == _selectedCategory.toUpperCase();
      final matchesSearch = p.name.toLowerCase().contains(_searchController.text.toLowerCase()) || p.category.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    // Sorting Rule based on _selectedSortMode:
    filteredProducts.sort((a, b) {
      if (_selectedSortMode == 'Name (A-Z)') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else if (_selectedSortMode == 'Price (Low-High)') {
        return a.retailPrice.compareTo(b.retailPrice);
      } else if (_selectedSortMode == 'Price (High-Low)') {
        return b.retailPrice.compareTo(a.retailPrice);
      } else if (_selectedSortMode == 'Stock (Low-High)') {
        return a.stockQuantity.compareTo(b.stockQuantity);
      } else {
        // Default FEFO: First-Expired, First-Out
        if (a.batchExpiryDate != null && b.batchExpiryDate != null) {
          return a.batchExpiryDate!.compareTo(b.batchExpiryDate!);
        }
        if (a.batchExpiryDate != null) return -1;
        if (b.batchExpiryDate != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    const currentRoute = '/pharmacy/pos';

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: MainAppBar(
            title: 'Pharmacy POS',
            actions: [
              IconButton(
                icon: const Icon(Icons.alarm_on_rounded),
                tooltip: 'Medication Refill Reminders',
                onPressed: () => Navigator.pushNamed(context, '/pharmacy/refills'),
              ),
            ],
          ),
          drawer: isDesktop ? null : Drawer(
            child: AppSidebar(
              userId: user.id,
              userName: user.name,
              userRole: user.activePrimaryRole.name.toUpperCase(),
              currentRoute: currentRoute,
              items: menuItems,
              onTap: (route) => MenuService.navigate(context, route, currentRoute),
            ),
          ),
          body: Row(
            children: [
              if (isDesktop)
                AppSidebar(
                  userId: user.id,
                  userName: user.name,
                  userRole: user.activePrimaryRole.name.toUpperCase(),
                  currentRoute: currentRoute,
                  items: menuItems,
                  onTap: (route) => MenuService.navigate(context, route, currentRoute),
                ),
              Expanded(
                child: _currentTab == 0
                    ? _buildPOSLayout(filteredProducts, categories, isWholesale, isMobile, isDesktop, categoryCounts: categoryCounts)
                    : _buildHistoryLayout(),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(child: _buildFooter()),
          floatingActionButton: (isMobile && _currentTab == 0)
              ? SafeArea(
                  child: FloatingActionButton.extended(
                    onPressed: () => _showMobileCart(),
                    label: Text('Cart (${ref.watch(cartProvider).length})'),
                    icon: const Icon(Icons.shopping_cart_checkout),
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _showMobileCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildCartSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildPOSLayout(List<Product> products, List<String> categories, bool isWholesale, bool isMobile, bool isDesktop, {Map<String, int>? categoryCounts}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    int crossAxisCount = isMobile ? 2 : (ResponsiveLayout.isTablet(context) ? 3 : 4);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pharmacy Header Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF047857), Color(0xFF065F46)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PHARMACY DISPENSARY',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                            ),
                            Text(
                              'FEFO Sorted • Expired Batches Quarantined • Batch & Dosage Tracking',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => Navigator.pushNamed(context, '/pharmacy/refills'),
                        icon: const Icon(Icons.alarm_on_rounded, size: 16),
                        label: const Text('REFILL ALERTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                // Full-width Search Input
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search medication by name, brand, or active ingredient...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Category Filter Rail with Live Item Counts & Sort Options
                Row(
                  children: [
                    Expanded(
                      child: CategoryFilterRail(
                        categories: categories,
                        selectedCategory: _selectedCategory,
                        categoryCounts: categoryCounts,
                        onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSortMode,
                          isDense: true,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          items: const [
                            DropdownMenuItem(value: 'FEFO Expiry', child: Text('Sort: FEFO Expiry')),
                            DropdownMenuItem(value: 'Name (A-Z)', child: Text('Sort: Name (A-Z)')),
                            DropdownMenuItem(value: 'Price (Low-High)', child: Text('Sort: Price (Low-High)')),
                            DropdownMenuItem(value: 'Price (High-Low)', child: Text('Sort: Price (High-Low)')),
                            DropdownMenuItem(value: 'Stock (Low-High)', child: Text('Sort: Stock (Low-High)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSortMode = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Product Cards Grid
                Expanded(
                  child: products.isEmpty
                      ? Align(alignment: Alignment.center, child: Text('No medications match your search', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppSpacing.s,
                            mainAxisSpacing: AppSpacing.s,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final hasPromo = product.isPromoActiveFor(false, _selectedCustomer);
                            final currentPrice = product.getPrice(false, customer: _selectedCustomer);

                            return ProductCard(
                              name: product.name,
                              category: product.category,
                              price: '₵${currentPrice.toStringAsFixed(2)}/${product.unit}',
                              originalPrice: hasPromo ? '₵${product.retailPrice.toStringAsFixed(2)}' : null,
                              stockQuantity: product.stockQuantity,
                              isUnlimited: product.isUnlimited,
                              unit: product.unit,
                              promoLabel: hasPromo ? '${product.discountPercentage.toInt()}% OFF' : null,
                              imageUrl: product.imageUrl,
                              requiresPrescription: product.requiresPrescription,
                              batchExpiryDate: product.batchExpiryDate,
                              batchNumber: product.batchNumber,
                              onTap: () => _addToCart(product, false),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        if (!isMobile)
          Container(
            width: isDesktop ? 380 : 300,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : AppColors.borderGray)),
            ),
            child: Material(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: _buildCartSection(),
            ),
          ),
      ],
    );
  }



  Widget _buildCartSection() {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final subtotal = cartNotifier.subtotal;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined),
              const SizedBox(width: 8),
              const Text('Current Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () {
                    cartNotifier.clear();
                    setState(() {
                      _drugDosages.clear();
                      _selectedDrugId = null;
                      _activeDosageController.clear();
                      _prescriptionController.clear();
                    });
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Customer Selection Row
        ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline, size: 20),
          title: Text(
            _selectedCustomer?.name ?? 'Select Customer',
            style: TextStyle(fontWeight: _selectedCustomer != null ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurface),
          ),
          subtitle: _selectedCustomer != null ? Text(_selectedCustomer!.phone, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedCustomer != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => setState(() {
                    _selectedCustomer = null;
                    _patientController.clear();
                    _patientPhoneController.clear();
                  }),
                ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () => _showCustomerDialog(),
              ),
            ],
          ),
          onTap: () => _showCustomerDialog(),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.xs),
            child: Column(
              children: [
                if (cartItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text('Cart is empty', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  )
                else
                  ...List.generate(cartItems.length, (index) {
                    final item = cartItems[index];
                  final drugId = item.product.id;
                  final hasDosage = _drugDosages.containsKey(drugId) && _drugDosages[drugId]!.trim().isNotEmpty;
                  final isCurrentSelected = _prescriptionExpanded && _selectedDrugId == drugId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isCurrentSelected 
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.05) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrentSelected 
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.4) 
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CartItemTile(
                          category: item.product.category,
                          name: item.product.name,
                          qty: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
                          weight: '${item.quantity} ${item.product.unit}',
                          amount: '₵${item.total.toStringAsFixed(2)}',
                          onDelete: () {
                            setState(() {
                              _drugDosages.remove(drugId);
                              if (_selectedDrugId == drugId) {
                                _selectedDrugId = null;
                                _activeDosageController.clear();
                              }
                              _syncFullPrescriptionText(cartItems.where((ci) => ci.product.id != drugId).toList());
                            });
                            cartNotifier.removeItem(index);
                          },
                          onIncrement: () => cartNotifier.updateQuantity(index, item.quantity + 1),
                          onDecrement: () {
                            if (item.quantity <= 1) {
                              setState(() {
                                _drugDosages.remove(drugId);
                                if (_selectedDrugId == drugId) {
                                  _selectedDrugId = null;
                                  _activeDosageController.clear();
                                }
                                _syncFullPrescriptionText(cartItems.where((ci) => ci.product.id != drugId).toList());
                              });
                            }
                            cartNotifier.updateQuantity(index, item.quantity - 1);
                          },
                        ),
                        // Direct Drug Prescription Trigger Chip
                        Padding(
                          padding: const EdgeInsets.only(left: 48, bottom: 6, right: 12),
                          child: InkWell(
                            onTap: () => _selectAndPrescribeDrug(drugId, cartItems),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasDosage 
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.1) 
                                    : (isCurrentSelected ? const Color(0xFF2E7D32).withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: hasDosage 
                                      ? const Color(0xFF2E7D32).withValues(alpha: 0.3) 
                                      : (isCurrentSelected ? const Color(0xFF2E7D32) : theme.dividerColor.withValues(alpha: 0.4)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasDosage ? Icons.check_circle_rounded : Icons.medication_liquid_outlined,
                                    size: 13,
                                    color: hasDosage ? const Color(0xFF2E7D32) : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      hasDosage 
                                          ? 'Rx: ${_drugDosages[drugId]}' 
                                          : 'Prescribe Dosage for this drug',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: hasDosage ? FontWeight.bold : FontWeight.w600,
                                        color: hasDosage 
                                            ? const Color(0xFF2E7D32) 
                                            : (isCurrentSelected ? const Color(0xFF2E7D32) : theme.colorScheme.onSurfaceVariant),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    hasDosage ? Icons.edit_outlined : Icons.chevron_right_rounded, 
                                    size: 13, 
                                    color: hasDosage ? const Color(0xFF2E7D32) : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              _buildPrescriptionSection(cartItems, theme),
            ],
          ),
        ),
      ),
        // Summary & Actions (Pinned at bottom, guaranteed no overflow)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL DUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                  Text('₵${subtotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode', 
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: ['Cash', 'MoMo', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: (cartItems.isEmpty || _isProcessingCheckout) ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  ),
                  child: _isProcessingCheckout
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('PROCEED TO PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: cartItems.isEmpty ? null : _saveAsDebt,
                  icon: const Icon(Icons.money_off, size: 16),
                  label: const Text('SAVE AS DEBT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                    side: BorderSide(color: Colors.orange.shade800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerAction(Icons.point_of_sale, 'New Sale', _currentTab == 0, () => setState(() => _currentTab = 0)),
          _footerAction(Icons.history, 'Transaction History', _currentTab == 1, () => setState(() => _currentTab = 1)),
        ],
      ),
    );
  }

  Widget _footerAction(IconData icon, String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          Text(label, style: TextStyle(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection(List<CartItem> cartItems, ThemeData theme) {
    if (cartItems.isEmpty) return const SizedBox.shrink();

    final hasRx = _hasRxRequired(cartItems);
    final isFilled = _prescriptionController.text.trim().isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: _prescriptionExpanded 
            ? const Color(0xFF2E7D32).withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _prescriptionExpanded || isFilled
              ? const Color(0xFF2E7D32) 
              : theme.dividerColor.withValues(alpha: 0.5),
          width: isFilled ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Toggle
          InkWell(
            onTap: () => setState(() => _prescriptionExpanded = !_prescriptionExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.medication_liquid_rounded, 
                    size: 18, 
                    color: (isFilled || _prescriptionExpanded) ? const Color(0xFF2E7D32) : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Prescription & Dosage', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: hasRx ? Colors.deepOrange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hasRx ? 'Rx Required' : 'Optional',
                                style: TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold, 
                                  color: hasRx ? Colors.deepOrange : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (isFilled && !_prescriptionExpanded) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Prescribed', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _prescriptionExpanded 
                              ? 'Configure dosage, receipt print & SMS delivery'
                              : (isFilled ? _prescriptionController.text : 'Tap to prescribe medication or dosage instructions'),
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _prescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Form
          if (_prescriptionExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Drug Selection Chips Row
                  const Text('Select Drug to Prescribe:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _drugSelectPill(
                          label: 'All Checkout Meds (${cartItems.length})',
                          isSelected: _selectedDrugId == null || _selectedDrugId == 'ALL',
                          isPrescribed: cartItems.isNotEmpty && cartItems.every((ci) => _drugDosages.containsKey(ci.product.id) && _drugDosages[ci.product.id]!.trim().isNotEmpty),
                          onTap: () {
                            setState(() {
                              _selectedDrugId = 'ALL';
                              _activeDosageController.text = '';
                            });
                          },
                        ),
                        ...cartItems.map((ci) {
                          final isSelected = _selectedDrugId == ci.product.id;
                          final hasDose = _drugDosages.containsKey(ci.product.id) && _drugDosages[ci.product.id]!.trim().isNotEmpty;
                          return _drugSelectPill(
                            label: ci.product.name,
                            isSelected: isSelected,
                            isPrescribed: hasDose,
                            onTap: () => _selectAndPrescribeDrug(ci.product.id, cartItems),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Active Drug Header & Action Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _selectedDrugId == null || _selectedDrugId == 'ALL' 
                                  ? Icons.layers_outlined 
                                  : Icons.medication_liquid_rounded, 
                              size: 14, 
                              color: const Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _selectedDrugId == null || _selectedDrugId == 'ALL'
                                    ? 'Prescribing for: All Medications'
                                    : 'Prescribing: ${_getDrugName(_selectedDrugId, cartItems)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2E7D32)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cartItems.length > 1) ...[
                        if (_selectedDrugId != null && _selectedDrugId != 'ALL')
                          InkWell(
                            onTap: () => _applyDosageToAllMeds(cartItems),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_all_rounded, size: 12, color: Colors.blue),
                                  const SizedBox(width: 3),
                                  const Text('Apply to All Meds', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _selectNextDrug(cartItems),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Next Med', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_rounded, size: 11),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 3. Active Dosage Input
                  TextField(
                    controller: _activeDosageController,
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: _selectedDrugId == null || _selectedDrugId == 'ALL'
                          ? 'e.g. 2 tabs 3 times daily after meals for 5 days (applies to all meds)...'
                          : 'Dosage for ${_getDrugName(_selectedDrugId, cartItems)}...',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onChanged: (v) {
                      setState(() {
                        final val = v.trim();
                        if (_selectedDrugId != null && _selectedDrugId != 'ALL') {
                          if (val.isEmpty) {
                            _drugDosages.remove(_selectedDrugId!);
                          } else {
                            _drugDosages[_selectedDrugId!] = val;
                          }
                        } else {
                          for (final ci in cartItems) {
                            if (val.isEmpty) {
                              _drugDosages.remove(ci.product.id);
                            } else {
                              _drugDosages[ci.product.id] = val;
                            }
                          }
                        }
                        _syncFullPrescriptionText(cartItems);
                      });
                    },
                  ),
                  const SizedBox(height: 6),

                  // 4. Quick frequency chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _dosageChip('2 tabs 3x daily', cartItems),
                        _dosageChip('1 tab 2x daily', cartItems),
                        _dosageChip('1 cap daily', cartItems),
                        _dosageChip('5ml 3x daily', cartItems),
                        _dosageChip('After meals', cartItems),
                        _dosageChip('Before bedtime', cartItems),
                        _dosageChip('For 5 days', cartItems),
                        _dosageChip('For 7 days', cartItems),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 5. Patient Name & Phone Row
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _patientController,
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            labelText: 'Patient Name',
                            hintText: 'Customer / Patient',
                            isDense: true,
                            prefixIcon: Icon(Icons.person, size: 14),
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _patientPhoneController,
                          style: const TextStyle(fontSize: 11),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                            LengthLimitingTextInputFormatter(16),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Patient Phone',
                            hintText: 'e.g. 0244123456 (SMS)',
                            isDense: true,
                            prefixIcon: Icon(Icons.phone, size: 14),
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 6. Doctor / Prescriber & Rx Serial No Row
                  Consumer(
                    builder: (context, ref, _) {
                      final currentUser = ref.watch(currentUserProvider);
                      final allUsers = ref.watch(userProvider);

                      final Set<String> prescriberOptions = {
                        'OTC / Self-Prescribed',
                        if (currentUser != null) '${currentUser.firstName} ${currentUser.surname}',
                        if (currentUser != null) 'Dr. ${currentUser.surname}',
                        ...allUsers.map((u) => '${u.firstName} ${u.surname}'),
                        'Dr. Appiah',
                        'Dr. Mensah',
                        'Dr. Owusu',
                        '+ Custom Prescriber / Doctor...',
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: prescriberOptions.contains(_selectedDoctor) ? _selectedDoctor : '+ Custom Prescriber / Doctor...',
                                  isDense: true,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  decoration: const InputDecoration(
                                    labelText: 'Doctor / Prescriber',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  ),
                                  items: prescriberOptions.map((opt) {
                                    return DropdownMenuItem<String>(
                                      value: opt,
                                      child: Text(
                                        opt,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: opt.startsWith('+') ? FontWeight.bold : FontWeight.normal,
                                          color: opt.startsWith('+') ? const Color(0xFF2E7D32) : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      _selectedDoctor = val;
                                      if (val == '+ Custom Prescriber / Doctor...') {
                                        _isCustomDoctor = true;
                                        if (_doctorController.text.trim().isEmpty) {
                                          _doctorController.text = 'Popo';
                                        }
                                      } else {
                                        _isCustomDoctor = false;
                                        _doctorController.text = val;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: _rxNumberController,
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    labelText: 'Rx Serial No',
                                    hintText: 'e.g. RX-2026-01',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isCustomDoctor) ...[
                            const SizedBox(height: 6),
                            TextField(
                              controller: _doctorController,
                              style: const TextStyle(fontSize: 11),
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Custom Prescriber / Doctor Name',
                                hintText: 'Enter doctor / prescriber name e.g. Popo',
                                isDense: true,
                                prefixIcon: const Icon(Icons.person_add_alt_1, size: 14),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.close, size: 14),
                                  onPressed: () => setState(() {
                                    _isCustomDoctor = false;
                                    _selectedDoctor = 'OTC / Self-Prescribed';
                                    _doctorController.clear();
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 7. Delivery Options (SMS or Receipt or Both)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRESCRIPTION DELIVERY CHANNELS', 
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _sendPrescriptionSms = !_sendPrescriptionSms),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _sendPrescriptionSms,
                                      onChanged: (v) => setState(() => _sendPrescriptionSms = v ?? false),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const Icon(Icons.sms_outlined, size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: const Text('Send via SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _includePrescriptionOnReceipt = !_includePrescriptionOnReceipt),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _includePrescriptionOnReceipt,
                                      onChanged: (v) => setState(() => _includePrescriptionOnReceipt = v ?? false),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const Icon(Icons.receipt_long_outlined, size: 14, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: const Text('Print on Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildDeliveryStatusBadge(),
                      ],
                    ),
                  ),

                  // 8. Compiled Prescription Summary Preview (if any prescribed)
                  if (_prescriptionController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 4),
                              Text(
                                'Compiled Prescription (${_drugDosages.length} of ${cartItems.length} meds prescribed):',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _prescriptionController.text,
                            style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dosageChip(String text, List<CartItem> cartItems) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_activeDosageController.text.trim().isEmpty) {
              _activeDosageController.text = text;
            } else {
              _activeDosageController.text += ' $text';
            }
            final newDosage = _activeDosageController.text.trim();
            if (_selectedDrugId != null && _selectedDrugId != 'ALL') {
              _drugDosages[_selectedDrugId!] = newDosage;
            } else {
              for (final ci in cartItems) {
                _drugDosages[ci.product.id] = newDosage;
              }
            }
            _syncFullPrescriptionText(cartItems);
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _drugSelectPill({
    required String label,
    required bool isSelected,
    required bool isPrescribed,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : (isPrescribed ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.12)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E7D32)
                  : (isPrescribed ? const Color(0xFF2E7D32).withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.25)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPrescribed ? Icons.check_circle_rounded : Icons.medication_liquid_rounded,
                size: 12,
                color: isSelected ? Colors.white : (isPrescribed ? const Color(0xFF2E7D32) : Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : (isPrescribed ? const Color(0xFF2E7D32) : Colors.black87),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusBadge() {
    if (_sendPrescriptionSms && _includePrescriptionOnReceipt) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _patientPhoneController.text.isNotEmpty
                    ? 'Delivery: SMS to ${_patientPhoneController.text} + Printed on Receipt'
                    : 'Delivery: SMS (enter phone) + Printed on Receipt',
                style: const TextStyle(fontSize: 9.5, color: Colors.green, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (_sendPrescriptionSms) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.sms_outlined, size: 12, color: Colors.blue),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _patientPhoneController.text.isNotEmpty
                    ? 'Delivery: SMS only (to ${_patientPhoneController.text})'
                    : 'Delivery: SMS only (enter phone above)',
                style: const TextStyle(fontSize: 9.5, color: Colors.blue, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (_includePrescriptionOnReceipt) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 12, color: Colors.teal),
            const SizedBox(width: 4),
            Expanded(
              child: const Text(
                'Delivery: Printed on Receipt only (No SMS)',
                style: TextStyle(fontSize: 9.5, color: Colors.teal, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: const Text(
                'Delivery: Pharmacy Record only (No SMS or Receipt print)',
                style: TextStyle(fontSize: 9.5, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHistoryLayout() {
    return PosTransactionHistoryView(
      onSwitchToNewSale: () => setState(() => _currentTab = 0),
      filterCategory: 'PHARMACY',
    );
  }
}



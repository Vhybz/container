import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/customer_model.dart';
import '../../models/product.dart';
import '../../models/sale_model.dart';
import '../../services/cart_provider.dart';
import '../../services/customer_provider.dart';
import '../../services/menu_service.dart';
import '../../services/product_service.dart';
import '../../services/receipt_service.dart';
import '../../services/sale_provider.dart';
import '../../services/user_provider.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/passcode_guard.dart';

class PharmacistPos extends ConsumerStatefulWidget {
  const PharmacistPos({super.key});

  @override
  ConsumerState<PharmacistPos> createState() => _PharmacistPosState();
}

class _PharmacistPosState extends ConsumerState<PharmacistPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _patientController = TextEditingController();
  final TextEditingController _doctorController = TextEditingController();
  final TextEditingController _rxNumberController = TextEditingController();

  String _selectedCategory = 'All';
  String _paymentMethod = 'Cash';
  Customer? _selectedCustomer;
  int _currentTab = 0; // 0 = New Sale, 1 = History

  final List<Product> _fallbackMeds = [
    Product(
      id: 'M1',
      name: 'Amoxicillin 500mg',
      category: 'Antibiotic',
      retailPrice: 25.0,
      wholesalePrice: 20.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 45,
      requiresPrescription: true,
      batchNumber: 'BAT-2024-001',
    ),
    Product(
      id: 'M2',
      name: 'Paracetamol Extra 500mg',
      category: 'Analgesic',
      retailPrice: 10.0,
      wholesalePrice: 8.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 120,
      requiresPrescription: false,
      batchNumber: 'BAT-2024-088',
    ),
    Product(
      id: 'M3',
      name: 'Ibuprofen 400mg',
      category: 'NSAID',
      retailPrice: 15.0,
      wholesalePrice: 12.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 80,
      requiresPrescription: false,
      batchNumber: 'BAT-2024-012',
    ),
    Product(
      id: 'M4',
      name: 'Metformin 850mg',
      category: 'Antidiabetic',
      retailPrice: 35.0,
      wholesalePrice: 30.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 60,
      requiresPrescription: true,
      batchNumber: 'BAT-2024-105',
    ),
    Product(
      id: 'M5',
      name: 'Vitamin C 1000mg Chewable',
      category: 'Supplement',
      retailPrice: 18.0,
      wholesalePrice: 15.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 200,
      requiresPrescription: false,
      batchNumber: 'BAT-2024-200',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _patientController.dispose();
    _doctorController.dispose();
    _rxNumberController.dispose();
    super.dispose();
  }

  void _addToCart(Product product, bool isWholesale) {
    final pcsPerPack = product.piecesPerPack ?? 1.0;
    final packPrice = product.effectivePackPrice;
    final packsPerBox = product.packsPerBox ?? 10.0;
    final boxPrice = product.boxPrice ?? (packPrice * packsPerBox);
    final unitName = product.unit.isNotEmpty ? product.unit : 'tablet';
    final customQtyController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double customQty = double.tryParse(customQtyController.text) ?? 1.0;
          final double totalPiecePrice = customQty * product.retailPrice;

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Dispense: ${product.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Unit Price: ₵${product.retailPrice.toStringAsFixed(2)} / $unitName', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. Dispense Individual $unitName(s):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customQtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: '$unitName Count',
                          suffixText: unitName,
                          isDense: true,
                        ),
                        onChanged: (v) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addItemToCart(product, customQty, product.retailPrice);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                      child: Text('Add ${customQty % 1 == 0 ? customQty.toInt() : customQty} $unitName(s) (₵${totalPiecePrice.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [1, 2, 3, 5, 10].map((count) {
                    return ActionChip(
                      label: Text('$count $unitName${count > 1 ? "s" : ""}', style: const TextStyle(fontSize: 10)),
                      onPressed: () {
                        setDialogState(() {
                          customQtyController.text = count.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                if (pcsPerPack > 1) ...[
                  const Divider(height: 24),
                  Text('2. Dispense Full Pack (${pcsPerPack.toInt()} $unitName(s)):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.inventory_2_outlined, color: Colors.white)),
                    title: Text('Full Pack (${pcsPerPack.toInt()} $unitName(s))', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('₵${packPrice.toStringAsFixed(2)} per pack'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final packProduct = product.copyWith(
                        name: '${product.name} (Pack)',
                        unit: 'pack',
                      );
                      _addItemToCart(packProduct, 1.0, packPrice);
                    },
                  ),
                ],
                if (packsPerBox > 1 && pcsPerPack > 1) ...[
                  const Divider(height: 24),
                  Text('3. Dispense Full Box (${packsPerBox.toInt()} packs):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.archive_outlined, color: Colors.white)),
                    title: Text('Full Box (${packsPerBox.toInt()} packs / ${(packsPerBox * pcsPerPack).toInt()} $unitName(s))', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('₵${boxPrice.toStringAsFixed(2)} per box'),
                    onTap: () {
                      Navigator.pop(ctx);
                      final boxProduct = product.copyWith(
                        name: '${product.name} (Box)',
                        unit: 'box',
                      );
                      _addItemToCart(boxProduct, 1.0, boxPrice);
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
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
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
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

    final sale = SaleRecord(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      items: saleItems,
      totalAmount: subtotal,
      totalDiscount: 0.0,
      totalCost: subtotal * 0.7,
      payments: [PaymentDetail(method: mode, amount: subtotal)],
      timestamp: DateTime.now(),
      cashierName: cashierName,
      cashierId: currentUser?.id ?? 'N/A',
      customerName: _selectedCustomer?.name ?? (_patientController.text.trim().isNotEmpty ? _patientController.text.trim() : null),
      customerPhone: _selectedCustomer?.phone,
      status: SaleStatus.completed,
      isVerified: true,
    );

    // Trigger printing dialog
    ReceiptService.printReceipt(sale, context: null);

    // Save sale to state
    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Dispense Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${sale.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Total Paid: ${currencyFormat.format(subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Payment Method: $_paymentMethod'),
            if (_hasRxRequired(cartItems) && (_patientController.text.isNotEmpty || _rxNumberController.text.isNotEmpty)) ...[
              const Divider(),
              if (_patientController.text.isNotEmpty) Text('Patient: ${_patientController.text}'),
              if (_doctorController.text.isNotEmpty) Text('Doctor: ${_doctorController.text}'),
              if (_rxNumberController.text.isNotEmpty) Text('Rx Number: ${_rxNumberController.text}'),
            ],
            const Divider(),
            const Text('Receipt sent to printer & inventory updated.'),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => ReceiptService.printReceipt(sale, context: context),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('RE-PRINT RECEIPT'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clear();
              setState(() {
                _patientController.clear();
                _doctorController.clear();
                _rxNumberController.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            child: const Text('OK / NEW SALE'),
          ),
        ],
      ),
    );
  }

  void _saveAsDebt() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    if (_selectedCustomer == null) {
      await _showCustomerDialog();
      if (_selectedCustomer == null) return;
    }

    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final currentUser = ref.read(currentUserProvider);

    final saleItems = cartItems.map((item) => SaleItem(
      product: item.product,
      quantity: item.quantity,
      priceAtSale: item.priceAtSale,
      originalPrice: item.originalPrice,
    )).toList();

    final sale = SaleRecord(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
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
    );

    await ref.read(saleHistoryProvider.notifier).addSale(sale);
    ref.read(cartProvider.notifier).clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sale saved as outstanding debt for ${_selectedCustomer!.name}')),
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
                            ? Center(
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
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                                itemBuilder: (context, index) {
                                  final c = filtered[index];
                                  return ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.person)),
                                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(c.phone),
                                    onTap: () {
                                      setState(() => _selectedCustomer = c);
                                      Navigator.pop(ctx);
                                    },
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
        title: const Row(
          children: [
            Icon(Icons.person_add_outlined, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Register New Customer'),
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
              setState(() => _selectedCustomer = newCust);
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
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isWholesale = ref.watch(isWholesaleProvider);
    final menuItems = MenuService.getMenuItemsForUser(user);
    final productsAsync = ref.watch(productsFutureProvider);

    // Prioritize database products if they exist
    List<Product> productsList = [];
    bool usingFallback = false;

    if (productsAsync.hasValue) {
      final dbProducts = productsAsync.value!
          .where((p) => !p.isDeleted)
          .where((p) {
            final cat = p.category.toUpperCase();
            return p.requiresPrescription ||
                   cat.contains('PHARM') || 
                   cat.contains('MED') || 
                   cat.contains('DRUG') || 
                   cat.contains('ANTIMALARIAL') || 
                   cat.contains('ANTIBIOTIC') || 
                   cat.contains('ANALGESIC') || 
                   cat.contains('NSAID') || 
                   cat.contains('COUGH') || 
                   cat.contains('COLD') || 
                   cat.contains('CARDIOVASCULAR') || 
                   cat.contains('GASTRO') || 
                   cat.contains('CONTRACEPTIVE') || 
                   cat.contains('SUPPLEMENT') || 
                   cat.contains('TOPICAL') || 
                   cat.contains('SEDATIVE') || 
                   cat.contains('GENERAL');
          })
          .toList();
      
      if (dbProducts.isNotEmpty) {
        productsList = dbProducts;
      } else if (productsAsync.value!.isEmpty) {
        // Only use fallbacks if the database is literally empty (new installation)
        productsList = _fallbackMeds;
        usingFallback = true;
      }
    } else {
      // Show fallbacks during initial load for UI responsiveness
      productsList = _fallbackMeds;
      usingFallback = true;
    }

    final categories = ['All', ...{...productsList.map((p) => p.category.toUpperCase())}];

    final filteredProducts = productsList.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category.toUpperCase() == _selectedCategory.toUpperCase();
      final matchesSearch = p.name.toLowerCase().contains(_searchController.text.toLowerCase()) || p.category.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    const currentRoute = '/pharmacy/pos';

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: MainAppBar(
            title: 'Pharmacy POS (${isWholesale ? "Wholesale" : "Retail"})',
            actions: const [],
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
                    ? _buildPOSLayout(filteredProducts, categories, isWholesale, isMobile, isDesktop)
                    : _buildHistoryLayout(),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(child: _buildFooter()),
        ),
      ),
    );
  }

  Widget _buildPOSLayout(List<Product> products, List<String> categories, bool isWholesale, bool isMobile, bool isDesktop) {
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
              children: [
                // Emmanuel Chemist Official Address Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('EMMANUEL CHEMIST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Location: Opposite Kaabere Main Clinic • GPS: BJ 0003-5661 • ea0005917@gmail.com', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Top controls: Retail vs Wholesale & Category Dropdown
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 45,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _modeButton('Retail', !isWholesale)),
                            Expanded(child: _modeButton('Wholesale', isWholesale)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    SizedBox(
                      width: isMobile ? 130 : 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                        isExpanded: true,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12), isDense: true),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                // Search Field
                SizedBox(
                  height: 45,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search medication or category...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                // Product Cards Grid
                Expanded(
                  child: products.isEmpty
                      ? Center(child: Text('No medications match your search', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
                            final hasPromo = product.isPromoActiveFor(isWholesale, _selectedCustomer);
                            final currentPrice = product.getPrice(isWholesale, customer: _selectedCustomer);

                            return ProductCard(
                              name: product.name,
                              category: product.category,
                              price: '₵${currentPrice.toStringAsFixed(2)}/${product.unit}',
                              originalPrice: hasPromo ? '₵${(isWholesale ? product.wholesalePrice : product.retailPrice).toStringAsFixed(2)}' : null,
                              stockQuantity: product.stockQuantity,
                              isUnlimited: product.isUnlimited,
                              unit: product.unit,
                              promoLabel: hasPromo ? '${product.discountPercentage.toInt()}% OFF' : null,
                              imageUrl: product.imageUrl,
                              requiresPrescription: product.requiresPrescription,
                              onTap: () => _addToCart(product, isWholesale),
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

  Widget _modeButton(String label, bool isSelected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        final newMode = label == 'Wholesale';
        ref.read(isWholesaleProvider.notifier).state = newMode;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m - 4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
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
                  onPressed: () => cartNotifier.clear(),
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
                  onPressed: () => setState(() => _selectedCustomer = null),
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
          child: cartItems.isEmpty
              ? Center(child: Text('Cart is empty', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return CartItemTile(
                      category: item.product.category,
                      name: item.product.name,
                      qty: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
                      weight: '${item.quantity} ${item.product.unit}',
                      amount: '₵${item.total.toStringAsFixed(2)}',
                      onDelete: () => cartNotifier.removeItem(index),
                      onIncrement: () => cartNotifier.updateQuantity(index, item.quantity + 1),
                      onDecrement: () => cartNotifier.updateQuantity(index, item.quantity - 1),
                    );
                  },
                ),
        ),
        if (_hasRxRequired(cartItems)) ...[
          Divider(height: 1, color: theme.dividerColor),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            color: Colors.amber.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prescription Details (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.deepOrange)),
                const SizedBox(height: 4),
                TextField(controller: _patientController, decoration: const InputDecoration(labelText: 'Patient Name', isDense: true)),
                const SizedBox(height: 4),
                TextField(controller: _doctorController, decoration: const InputDecoration(labelText: 'Doctor Name', isDense: true)),
                const SizedBox(height: 4),
                TextField(controller: _rxNumberController, decoration: const InputDecoration(labelText: 'Rx Serial No', isDense: true)),
              ],
            ),
          ),
        ],
        // Summary & Actions
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TOTAL DUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                  Text('₵${subtotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Mode', isDense: true),
                items: ['Cash', 'MoMo', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cartItems.isEmpty ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  ),
                  child: const Text('PROCEED TO PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: cartItems.isEmpty ? null : _saveAsDebt,
                  icon: const Icon(Icons.money_off, size: 18),
                  label: const Text('SAVE AS DEBT', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildHistoryLayout() {
    final salesHistory = ref.watch(saleHistoryProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pharmacy Dispensing History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: salesHistory.isEmpty
                ? const Center(child: Text('No dispensing records found.'))
                : ListView.separated(
                    itemCount: salesHistory.length,
                    separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                    itemBuilder: (context, index) {
                      final sale = salesHistory[index];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF2E7D32), child: Icon(Icons.receipt, color: Colors.white)),
                        title: Text('Invoice ${sale.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('MMM dd, yyyy HH:mm').format(sale.timestamp)} • Patient: ${sale.customerName ?? "Walk-In"}'),
                        trailing: Text('GHS ${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32))),
                        onTap: () => ReceiptService.printReceipt(sale, context: context),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

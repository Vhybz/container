import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/customer_model.dart';
import '../../models/product.dart';
import '../../models/sale_model.dart';
import '../../models/user_model.dart';
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

class TechPos extends ConsumerStatefulWidget {
  const TechPos({super.key});

  @override
  ConsumerState<TechPos> createState() => _TechPosState();
}

class _TechPosState extends ConsumerState<TechPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _imeiController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedTechnician = 'Lead Technician Frank';
  String _paymentMethod = 'MoMo';
  Customer? _selectedCustomer;
  int _currentTab = 0; // 0 = New Sale, 1 = History

  final List<String> _defaultTechReps = [
    'Lead Technician Frank',
    'Tech Rep Alex',
    'Tech Rep Sam',
  ];

  final List<Product> _fallbackTech = [
    Product(
      id: 'T1',
      name: 'iPhone 15 Pro 128GB',
      category: 'PHONE & ACCESSORIES',
      retailPrice: 14500.0,
      wholesalePrice: 14000.0,
      imageUrl: '',
      unit: 'unit',
      stockQuantity: 10,
      requiresImei: true,
    ),
    Product(
      id: 'T2',
      name: 'Samsung Galaxy S24 Ultra',
      category: 'PHONE & ACCESSORIES',
      retailPrice: 15200.0,
      wholesalePrice: 14800.0,
      imageUrl: '',
      unit: 'unit',
      stockQuantity: 8,
      requiresImei: true,
    ),
    Product(
      id: 'T3',
      name: '20W USB-C Fast Charger',
      category: 'PHONE & ACCESSORIES',
      retailPrice: 180.0,
      wholesalePrice: 150.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 50,
      requiresImei: false,
    ),
    Product(
      id: 'T4',
      name: 'MagSafe Clear Case',
      category: 'PHONE & ACCESSORIES',
      retailPrice: 120.0,
      wholesalePrice: 90.0,
      imageUrl: '',
      unit: 'pcs',
      stockQuantity: 75,
      requiresImei: false,
    ),
    Product(
      id: 'T5',
      name: 'iPhone Screen Repair (Labor + Part)',
      category: 'PHONE & ACCESSORIES',
      retailPrice: 1200.0,
      wholesalePrice: 1100.0,
      imageUrl: '',
      unit: 'service',
      isService: true,
      isUnlimited: true,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _imeiController.dispose();
    super.dispose();
  }

  void _addToCart(Product product, bool isWholesale) {
    final price = product.getPrice(isWholesale, customer: _selectedCustomer);
    final orig = isWholesale ? product.wholesalePrice : product.retailPrice;
    ref.read(cartProvider.notifier).addItemWithCustomPrice(product, 1.0, price, orig);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _hasImeiRequired(List<CartItem> cart) {
    return cart.any((item) => item.product.requiresImei || item.product.category.toUpperCase().contains('PHONE'));
  }

  void _checkout() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    if (_hasImeiRequired(cartItems) && _imeiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device in cart requires valid IMEI/Serial Number.'), backgroundColor: Colors.red),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final String cashierName = currentUser != null ? '${currentUser.firstName} ${currentUser.surname}' : 'Tech Rep';
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
      customerName: _selectedCustomer?.name ?? 'Walk-In Customer',
      customerPhone: _selectedCustomer?.phone,
      status: SaleStatus.completed,
      isVerified: true,
    );

    // Trigger printing receipt
    ReceiptService.printReceipt(sale, context: null);

    // Save sale to state
    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('Tech Purchase & Warranty Issued'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${sale.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Total Paid: ${currencyFormat.format(subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Payment Method: $_paymentMethod'),
            if (_hasImeiRequired(cartItems) && _imeiController.text.isNotEmpty) ...[
              const Divider(),
              Text('Registered IMEI: ${_imeiController.text}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
            ],
            const Divider(),
            const Text('12 Months Warranty Certificate Active.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
                _imeiController.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
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
      cashierName: currentUser?.name ?? 'Tech Rep',
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
                      icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFE65100)),
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
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
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
            Icon(Icons.person_add_outlined, color: Color(0xFFE65100)),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
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
            final name = p.name.toUpperCase();
            final isTechCategory = p.requiresImei || 
                   cat.contains('PHONE') || 
                   cat.contains('TECH') || 
                   cat.contains('DEVICE') || 
                   cat.contains('ACCESSOR') || 
                   cat.contains('SMART') || 
                   cat.contains('CHARGER') || 
                   cat.contains('POWER') || 
                   cat.contains('CASE') || 
                   cat.contains('PROTECT') || 
                   cat.contains('SCREEN') || 
                   cat.contains('AUDIO') || 
                   cat.contains('SOUND') || 
                   cat.contains('WEARABLE') || 
                   cat.contains('MOUNT') || 
                   cat.contains('HOLDER') || 
                   cat.contains('REPAIR') || 
                   cat.contains('SERVICE');
            
            final isBarberStuff = cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM') || cat.contains('SALON');
            
            // Show if it's a tech category, or any tech-related name, ensuring no pharmacy or barber items.
            return isTechCategory && 
                   !p.requiresPrescription && 
                   !cat.contains('PHARM') && 
                   !cat.contains('MED') &&
                   !isBarberStuff;
          })
          .toList();
      
      if (dbProducts.isNotEmpty) {
        productsList = dbProducts;
      } else if (productsAsync.value!.isEmpty) {
        // Only use fallbacks if the database is literally empty (new installation)
        productsList = _fallbackTech;
        usingFallback = true;
      }
    } else {
      // Show fallbacks during initial load for UI responsiveness
      productsList = _fallbackTech;
      usingFallback = true;
    }

    final categories = ['All', ...{...productsList.map((p) => p.category.toUpperCase())}];

    final filteredProducts = productsList.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category.toUpperCase() == _selectedCategory.toUpperCase();
      final matchesSearch = p.name.toLowerCase().contains(_searchController.text.toLowerCase()) || p.category.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    const currentRoute = '/tech/pos';

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: MainAppBar(
            title: 'Tech Shop POS (${isWholesale ? "Wholesale" : "Retail"})',
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
                      hintText: 'Search tech, devices, or accessories...',
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
                      ? Center(child: Text('No devices or accessories match your search', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
                              requiresImei: product.requiresImei,
                              isService: product.isService,
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
    final users = ref.watch(userProvider);
    final activeStaffTechReps = users
        .where((u) => !u.isDeleted && u.status == AccountStatus.approved)
        .map((u) => '${u.firstName} ${u.surname}')
        .toList();
    final techReps = activeStaffTechReps.isNotEmpty ? activeStaffTechReps : _defaultTechReps;
    if (!techReps.contains(_selectedTechnician)) {
      _selectedTechnician = techReps.first;
    }

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
        // Repairer / Tech Rep Assignment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedTechnician,
            decoration: const InputDecoration(labelText: 'Assign Repairer / Tech Rep', isDense: true, prefixIcon: Icon(Icons.build_circle_outlined, size: 20)),
            items: techReps.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => _selectedTechnician = v!),
          ),
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
        if (_hasImeiRequired(cartItems)) ...[
          Divider(height: 1, color: theme.dividerColor),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            color: Colors.deepOrange.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('IMEI / Serial Number Registration *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.deepOrange)),
                const SizedBox(height: 4),
                TextField(
                  controller: _imeiController,
                  decoration: const InputDecoration(
                    labelText: 'Device IMEI / Serial No *',
                    prefixIcon: Icon(Icons.qr_code),
                    isDense: true,
                  ),
                ),
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
                items: ['MoMo', 'Cash', 'Card'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v!),
              ),
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cartItems.isEmpty ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
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
          const Text('Tech Shop Sales & Warranty History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: salesHistory.isEmpty
                ? const Center(child: Text('No tech sales records found.'))
                : ListView.separated(
                    itemCount: salesHistory.length,
                    separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                    itemBuilder: (context, index) {
                      final sale = salesHistory[index];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE65100), child: Icon(Icons.phone_android, color: Colors.white)),
                        title: Text('Invoice ${sale.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('MMM dd, yyyy HH:mm').format(sale.timestamp)} • Customer: ${sale.customerName ?? "Walk-In"}'),
                        trailing: Text('GHS ${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFE65100))),
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

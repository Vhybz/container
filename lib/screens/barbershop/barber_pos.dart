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
import '../../services/sms_service.dart';
import '../../models/barbershop_models.dart';
import '../../services/barber_records_provider.dart';
import '../../services/barbershop_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/passcode_guard.dart';

class BarberPos extends ConsumerStatefulWidget {
  const BarberPos({super.key});

  @override
  ConsumerState<BarberPos> createState() => _BarberPosState();
}

class _BarberPosState extends ConsumerState<BarberPos> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tipController = TextEditingController(text: '0.0');
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedBarber = 'King Mojo';
  String _clientGender = 'Male';
  String _clientAgeCategory = 'Adult';
  String _paymentMethod = 'Cash';
  Customer? _selectedCustomer;
  int _currentTab = 0; // 0 = New Sale, 1 = History

  final List<String> _customBarbers = [];
  final List<String> _barbers = [
    'King Mojo',
  ];

  final TextEditingController _historySearchController = TextEditingController();
  String _historyBarberFilter = 'All';
  String _historyServiceFilter = 'All';
  String _historyDateFilter = 'All Time';
  DateTimeRange? _historyCustomRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cartProvider.notifier).registerPos('/barbershop/pos');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tipController.dispose();
    _clientNameController.dispose();
    _clientPhoneController.dispose();
    _childNameController.dispose();
    _parentPhoneController.dispose();
    _historySearchController.dispose();
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

  void _checkout() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final String cashierName = currentUser != null ? '${currentUser.firstName} ${currentUser.surname}' : 'Barber Rep';
    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final tip = double.tryParse(_tipController.text) ?? 0.0;
    final grandTotal = subtotal + tip;

    final nameInput = _clientNameController.text.trim();
    final phoneInput = _clientPhoneController.text.trim();
    final String clientName = nameInput.isNotEmpty ? nameInput : (_selectedCustomer?.name ?? 'Walk-In Client');
    final String clientPhone = phoneInput.isNotEmpty ? phoneInput : (_selectedCustomer?.phone ?? '');
    final String fullClientDisplay = '$clientName ($_clientGender • $_clientAgeCategory)';
    final String clientGenderSaved = _clientGender;
    final String clientAgeSaved = _clientAgeCategory;
    final String paymentMethodSaved = _paymentMethod;

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
      branchCode: currentUser?.branchCode ?? 'MAIN',
      items: saleItems,
      totalAmount: grandTotal,
      totalDiscount: 0.0,
      totalCost: subtotal * 0.7,
      payments: [PaymentDetail(method: mode, amount: grandTotal)],
      timestamp: DateTime.now(),
      cashierName: '$_selectedBarber (Cashier: $cashierName)',
      cashierId: currentUser?.id ?? 'N/A',
      customerName: fullClientDisplay,
      customerPhone: clientPhone.isNotEmpty ? clientPhone : null,
      status: SaleStatus.completed,
      isVerified: true,
    );

    // Trigger printing receipt
    ReceiptService.printReceipt(sale, context: null);

    // Save sale to state
    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    // Resolve service names for records and SMS
    final String serviceNames = saleItems
        .where((i) => i.product.isService || i.product.category.toUpperCase().contains('BARBER'))
        .map((i) => i.product.name)
        .join(', ');
    final String resolvedServiceName = serviceNames.isNotEmpty ? serviceNames : 'Haircut / Shave Service';

    // Save permanent record to BarberRecords provider (preserved forever)
    final String paymentMethodLabel = _paymentMethod;
    final List<CartItem> serviceCartItems = cartItems
        .where((i) => i.product.isService || i.product.category.toUpperCase().contains('BARBER') || i.product.category.toUpperCase().contains('HAIR') || i.product.category.toUpperCase().contains('BEARD'))
        .toList();

    if (serviceCartItems.isNotEmpty) {
      for (final item in serviceCartItems) {
        final double fixedComm = item.product.serviceCommission > 0
            ? (item.product.serviceCommission * item.quantity)
            : ref.read(barberRecordsProvider.notifier).resolveCommissionAmount(item.product.name, price: item.priceAtSale, product: item.product);
        final double commRate = item.priceAtSale > 0 ? ((fixedComm / item.priceAtSale) * 100.0) : 40.0;

        await ref.read(barberRecordsProvider.notifier).recordService(
          customerName: clientName,
          customerPhone: clientPhone,
          service: item.product.name,
          barber: _selectedBarber,
          price: item.priceAtSale,
          tip: item == serviceCartItems.first ? tip : 0.0,
          paymentMethod: paymentMethodLabel,
          attendant: cashierName,
          saleId: sale.id,
          source: 'POS',
          notes: _clientAgeCategory == 'Kid' ? 'Kid cut (Parent: ${_parentPhoneController.text.trim()})' : null,
          timestamp: sale.timestamp,
          commissionRate: commRate,
          commissionAmount: fixedComm,
          product: item.product,
        );
      }
    } else {
      final double fixedComm = ref.read(barberRecordsProvider.notifier).resolveCommissionAmount(resolvedServiceName, price: grandTotal);
      final double commRate = grandTotal > 0 ? ((fixedComm / grandTotal) * 100.0) : 40.0;

      await ref.read(barberRecordsProvider.notifier).recordService(
        customerName: clientName,
        customerPhone: clientPhone,
        service: resolvedServiceName,
        barber: _selectedBarber,
        price: grandTotal,
        tip: tip,
        paymentMethod: paymentMethodLabel,
        attendant: cashierName,
        saleId: sale.id,
        source: 'POS',
        notes: _clientAgeCategory == 'Kid' ? 'Kid cut (Parent: ${_parentPhoneController.text.trim()})' : null,
        timestamp: sale.timestamp,
        commissionRate: commRate,
        commissionAmount: fixedComm,
      );
    }

    // Trigger instant post-haircut SMS to client if phone is provided

    if (_clientAgeCategory == 'Kid') {
      // Kid: send sweet SMS to parent's phone with child's name
      final String childName = _childNameController.text.trim().isNotEmpty
          ? _childNameController.text.trim()
          : clientName;
      final String parentPhone = _parentPhoneController.text.trim().isNotEmpty
          ? _parentPhoneController.text.trim()
          : clientPhone;
      if (parentPhone.isNotEmpty) {
        SmsService.sendKidHaircutSms(
          childName: childName,
          parentPhone: parentPhone,
          serviceName: resolvedServiceName,
          barberName: _selectedBarber,
        );
      }
    } else {
      // Adult: send normal post-haircut SMS
      if (clientPhone.isNotEmpty) {
        SmsService.sendPostHaircutSms(
          name: clientName,
          phone: clientPhone,
          serviceName: resolvedServiceName,
          barberName: _selectedBarber,
        );
      }
    }

    // Clean cart and all checkout fields immediately after sale
    ref.read(cartProvider.notifier).clear();
    setState(() {
      _clientNameController.clear();
      _clientPhoneController.clear();
      _childNameController.clear();
      _parentPhoneController.clear();
      _tipController.text = '0.0';
      _clientGender = 'Male';
      _clientAgeCategory = 'Adult';
      _paymentMethod = 'Cash';
      _selectedCustomer = null;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cut, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Barbershop Service Completed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${sale.id}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Barber Assigned: $_selectedBarber', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Client: $clientName'),
            Text('Category: $clientGenderSaved • $clientAgeSaved', style: const TextStyle(fontSize: 12, color: Colors.blue)),
            if (clientPhone.isNotEmpty) Text('Phone: $clientPhone', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text('Total Paid: ${currencyFormat.format(grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (tip > 0) Text('Includes Barber Tip: ${currencyFormat.format(tip)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
            Text('Payment Method: $paymentMethodSaved'),
            const Divider(),
            const Text('Receipt issued successfully.'),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => ReceiptService.printReceipt(sale, context: context),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('RE-PRINT RECEIPT'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: const Text('OK / NEW CLIENT'),
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
    final debtCustName = _selectedCustomer!.name;

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
      cashierName: currentUser?.name ?? 'Barber Rep',
      cashierId: currentUser?.id ?? 'N/A',
      customerName: _selectedCustomer!.name,
      customerPhone: _selectedCustomer!.phone,
      status: SaleStatus.completed,
      isVerified: true,
    );

    await ref.read(saleHistoryProvider.notifier).addSale(sale);

    // Save permanent record to BarberRecords provider
    final String debtClientName = _selectedCustomer?.name ?? 'Client';
    final String debtClientPhone = _selectedCustomer?.phone ?? '';
    final List<CartItem> debtServiceCartItems = cartItems
        .where((i) => i.product.isService || i.product.category.toUpperCase().contains('BARBER') || i.product.category.toUpperCase().contains('HAIR') || i.product.category.toUpperCase().contains('BEARD'))
        .toList();

    if (debtServiceCartItems.isNotEmpty) {
      for (final item in debtServiceCartItems) {
        await ref.read(barberRecordsProvider.notifier).recordService(
          customerName: debtClientName,
          customerPhone: debtClientPhone,
          service: item.product.name,
          barber: _selectedBarber,
          price: item.priceAtSale,
          tip: 0.0,
          paymentMethod: 'Debt',
          attendant: currentUser?.name ?? 'Barber Rep',
          saleId: sale.id,
          source: 'POS Debt',
          timestamp: sale.timestamp,
        );
      }
    } else {
      await ref.read(barberRecordsProvider.notifier).recordService(
        customerName: debtClientName,
        customerPhone: debtClientPhone,
        service: 'Haircut / Shave Service',
        barber: _selectedBarber,
        price: subtotal,
        tip: 0.0,
        paymentMethod: 'Debt',
        attendant: currentUser?.name ?? 'Barber Rep',
        saleId: sale.id,
        source: 'POS Debt',
        timestamp: sale.timestamp,
      );
    }

    // Clean cart and all checkout fields immediately after debt sale
    ref.read(cartProvider.notifier).clear();
    setState(() {
      _clientNameController.clear();
      _clientPhoneController.clear();
      _childNameController.clear();
      _parentPhoneController.clear();
      _tipController.text = '0.0';
      _clientGender = 'Male';
      _clientAgeCategory = 'Adult';
      _paymentMethod = 'Cash';
      _selectedCustomer = null;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved as debt for $debtCustName')),
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
                    const Text('Select Client'),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF1565C0)),
                      tooltip: 'Register New Client',
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
                                    const Text('No clients found', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddNewCustomerModal(ctx),
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('Register New Client'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
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
            Icon(Icons.person_add_outlined, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Register New Client'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Client Full Name', prefixIcon: Icon(Icons.person_outline)),
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
                SnackBar(content: Text('Client "${newCust.name}" registered and selected!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
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

    if (productsAsync.hasValue) {
      final dbProducts = productsAsync.value!
          .where((p) => !p.isDeleted)
          .where((p) {
            final cat = p.category.toUpperCase();
            final name = p.name.toUpperCase();
            final isBarberCategory = cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM') || cat.contains('SALON') || cat.contains('STYL');
            final isService = p.isService || p.unit.toLowerCase() == 'service';
            final isTechRepair = cat.contains('REPAIR') || name.contains('IPHONE') || name.contains('BATTERY') || name.contains('CHARGING') || name.contains('FLASHING') || name.contains('SCREEN') || cat.contains('PHONE') || cat.contains('TECH');
            
            // Show if it's a barber category, or a non-tech service. Ensure no pharmacy items.
            return (isBarberCategory || (isService && !isTechRepair)) && 
                   !p.requiresPrescription && 
                   !cat.contains('PHARM') && 
                   !cat.contains('MED');
          })
          .toList();
      
      final activeProds = productsAsync.value!.where((p) => !p.isDeleted && !p.requiresPrescription).toList();
      productsList = dbProducts.isNotEmpty ? dbProducts : activeProds;
    }

    final categories = ['All', ...{...productsList.map((p) => p.category.toUpperCase())}];

    final filteredProducts = productsList.where((p) {
      final matchesCategory = _selectedCategory == 'All' || p.category.toUpperCase() == _selectedCategory.toUpperCase();
      final matchesSearch = p.name.toLowerCase().contains(_searchController.text.toLowerCase()) || p.category.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    const currentRoute = '/barbershop/pos';

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const MainAppBar(
            title: 'Barbershop POS',
            actions: [],
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
                // Top Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                          selectedColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                // Search Bar
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search service or grooming product...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                      ? Center(child: Text('No grooming services or products match your search', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
                              isService: product.isService,
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



  Widget _tipChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      padding: EdgeInsets.zero,
      onPressed: () {
        final current = double.tryParse(_tipController.text) ?? 0.0;
        setState(() {
          _tipController.text = (current + amount).toStringAsFixed(0);
        });
      },
    );
  }

  Widget _paymentChip(String method, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              method,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewBarberDialog() {
    final firstNameController = TextEditingController();
    final surnameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Register New Barber / Stylist'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'Barber First Name'),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: surnameController,
              decoration: const InputDecoration(labelText: 'Surname'),
            ),
            const SizedBox(height: AppSpacing.m),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (firstNameController.text.trim().isEmpty) return;
              final currentUser = ref.read(currentUserProvider);
              final String firstName = firstNameController.text.trim();
              final String surname = surnameController.text.trim().isEmpty ? 'Stylist' : surnameController.text.trim();
              final String fullName = '$firstName $surname';

              final newBarber = UserAccount(
                id: UuidUtils.generate(),
                firstName: firstName,
                surname: surname,
                email: '${firstName.toLowerCase()}_barber${DateTime.now().millisecondsSinceEpoch}@barber.local',
                phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                role: UserRole.barber,
                branchCode: currentUser?.branchCode,
                status: AccountStatus.approved,
              );

              if (!_customBarbers.contains(fullName)) {
                _customBarbers.add(fullName);
              }

              setState(() {
                _selectedBarber = fullName;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Barber "$fullName" registered and assigned!')),
              );

              Navigator.pop(ctx);

              try {
                await ref.read(userProvider.notifier).addAccount(newBarber);
              } catch (e) {
                debugPrint('Error saving new barber: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: const Text('CREATE & ASSIGN'),
          ),
        ],
      ),
    );
  }

  Widget _genderChip(String gender, IconData icon) {
    final isSelected = _clientGender == gender;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _clientGender = gender),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 2),
              Text(gender, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ageChip(String ageGroup, IconData icon) {
    final isSelected = _clientAgeCategory == ageGroup;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _clientAgeCategory = ageGroup),
        child: Container(
          height: 28,
          decoration: BoxDecoration(
            color: isSelected ? (ageGroup == 'Kid' ? Colors.orange.shade800 : const Color(0xFF1565C0)) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? (ageGroup == 'Kid' ? Colors.orange.shade800 : const Color(0xFF1565C0)) : Colors.grey.shade400),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isSelected ? Colors.white : Colors.grey.shade700),
              const SizedBox(width: 2),
              Text(ageGroup, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSection() {
    final theme = Theme.of(context);
    final users = ref.watch(userProvider);
    final activeStaffBarbers = users
        .where((u) => !u.isDeleted && u.status == AccountStatus.approved && u.role == UserRole.barber)
        .map((u) => '${u.firstName} ${u.surname}')
        .toList();

    final barbers = <String>{...activeStaffBarbers, ..._customBarbers, ..._barbers}.toList();
    if (!barbers.contains(_selectedBarber) && barbers.isNotEmpty) {
      _selectedBarber = barbers.first;
    }

    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final subtotal = cartNotifier.subtotal;
    final tip = double.tryParse(_tipController.text) ?? 0.0;
    final grandTotal = subtotal + tip;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              const Icon(Icons.cut_outlined),
              const SizedBox(width: 8),
              const Text('Client Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        // Barber Assignment & On-the-fly Add Barber
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedBarber,
                  decoration: const InputDecoration(labelText: 'Assign Barber / Stylist', isDense: true, prefixIcon: Icon(Icons.person_pin_outlined, size: 18)),
                  items: barbers.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _selectedBarber = v!),
                ),
              ),
              const SizedBox(width: 4),
              if (ref.read(currentUserProvider)?.role == UserRole.admin || ref.read(currentUserProvider)?.role == UserRole.superAdmin)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF1565C0)),
                  tooltip: 'Add New Barber',
                  onPressed: _showAddNewBarberDialog,
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Client Info Card (Name, Phone, Gender, Age Group)
        Container(
          padding: const EdgeInsets.all(AppSpacing.s),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Client Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  TextButton.icon(
                    onPressed: () => _showCustomerDialog(),
                    icon: const Icon(Icons.contacts_outlined, size: 12),
                    label: Text(_selectedCustomer == null ? 'Saved Clients' : 'Change', style: const TextStyle(fontSize: 10)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _clientPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone No.',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gender', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _genderChip('Male', Icons.male),
                            const SizedBox(width: 4),
                            _genderChip('Female', Icons.female),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Age Group', style: TextStyle(fontSize: 9, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _ageChip('Adult', Icons.face),
                            const SizedBox(width: 4),
                            _ageChip('Kid', Icons.child_care),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Kid-specific fields: Child's Name & Parent's Phone
              if (_clientAgeCategory == 'Kid') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.child_care, size: 14, color: Colors.orange.shade800),
                          const SizedBox(width: 4),
                          Text('Kid Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange.shade800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _childNameController,
                              decoration: InputDecoration(
                                labelText: 'Child\'s Name',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                prefixIcon: const Icon(Icons.face, size: 16),
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _parentPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Parent\'s Phone',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                prefixIcon: const Icon(Icons.phone, size: 16),
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: cartItems.isEmpty
              ? Center(child: Text('No services selected', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
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
        // Tip Field & Preset Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _tipController,
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Barber Tip / Gratuity (GHS)', isDense: true, prefixText: '₵ '),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tipChip('+₵5', 5),
                    const SizedBox(width: 4),
                    _tipChip('+₵10', 10),
                    const SizedBox(width: 4),
                    _tipChip('+₵20', 20),
                    const SizedBox(width: 4),
                    _tipChip('+₵50', 50),
                    const SizedBox(width: 4),
                    ActionChip(
                      label: const Text('Clear', style: TextStyle(fontSize: 10, color: Colors.red)),
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _tipController.text = '0.0'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                  Text('TOTAL DUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                  Text('₵${grandTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(child: _paymentChip('Cash', Icons.payments_outlined)),
                  const SizedBox(width: 6),
                  Expanded(child: _paymentChip('MoMo', Icons.phone_android_outlined)),
                  const SizedBox(width: 6),
                  Expanded(child: _paymentChip('Card', Icons.credit_card_outlined)),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: cartItems.isEmpty ? null : _checkout,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('COMPLETE CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: cartItems.isEmpty ? null : _saveAsDebt,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('SAVE TO CLIENT TAB / DEBT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
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
    final allRecords = ref.watch(barberRecordsProvider);
    final salesHistory = ref.watch(saleHistoryProvider);
    final theme = Theme.of(context);

    // Dynamic multi-criteria filter supporting Barber, Haircut, and Customer Name
    final filtered = ref.watch(barberRecordsProvider.notifier).filter(
      searchQuery: _historySearchController.text,
      barber: _historyBarberFilter,
      service: _historyServiceFilter,
      dateFilter: _historyDateFilter,
      customRange: _historyCustomRange,
    );

    // Unique Barber list for dropdown
    final allBarbers = <String>{'All', ..._barbers, ...allRecords.map((r) => r.barber)}
        .where((b) => b.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    // Unique Haircut/Service list for dropdown
    final allServices = <String>{'All', ...allRecords.map((r) => r.service)}
        .where((s) => s.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    // KPIs for current filtered view
    final double totalRevenue = filtered.fold(0.0, (sum, r) => sum + r.totalPaid);
    final double totalCommission = filtered.fold(0.0, (sum, r) => sum + r.effectiveCommission);
    final double avgTicket = filtered.isNotEmpty ? (totalRevenue / filtered.length) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Quick KPI chips
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shaving & Haircut Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Filter by barber, haircut style, or search client name', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.cut, size: 14, color: Color(0xFF1565C0)),
                    label: Text('${filtered.length} Cuts / Shaves', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Chip(
                    avatar: const Icon(Icons.monetization_on, size: 14, color: Colors.green),
                    label: Text(currencyFormat.format(totalRevenue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Chip(
                    avatar: const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFF2E7D32)),
                    label: Text('Comm: ${currencyFormat.format(totalCommission)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  Chip(
                    avatar: const Icon(Icons.analytics_outlined, size: 14, color: Colors.orange),
                    label: Text('Avg: ${currencyFormat.format(avgTicket)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          // Search Bar (Customer Name / Phone / Service)
          SizedBox(
            height: 42,
            child: TextField(
              controller: _historySearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by client name, phone number, or haircut style...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _historySearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _historySearchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),

          // Filter Dropdowns Row: Barber & Haircut
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Barber Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  color: theme.colorScheme.surface,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 15, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: allBarbers.contains(_historyBarberFilter) ? _historyBarberFilter : 'All',
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        items: allBarbers.map((barber) {
                          return DropdownMenuItem(
                            value: barber,
                            child: Text(barber == 'All' ? 'All Barbers' : 'Barber: $barber'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _historyBarberFilter = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Haircut / Service Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  color: theme.colorScheme.surface,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_cut, size: 15, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: allServices.contains(_historyServiceFilter) ? _historyServiceFilter : 'All',
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        items: allServices.map((service) {
                          return DropdownMenuItem(
                            value: service,
                            child: Text(
                              service == 'All'
                                  ? 'All Haircuts & Services'
                                  : (service.length > 28 ? '${service.substring(0, 26)}...' : service),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _historyServiceFilter = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Clear all filters button if any filter is active
              if (_historyBarberFilter != 'All' ||
                  _historyServiceFilter != 'All' ||
                  _historyDateFilter != 'All Time' ||
                  _historySearchController.text.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.filter_alt_off, size: 14),
                  label: const Text('Clear Filters', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _historySearchController.clear();
                      _historyBarberFilter = 'All';
                      _historyServiceFilter = 'All';
                      _historyDateFilter = 'All Time';
                      _historyCustomRange = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),

          // Date Range Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPosDateChip('All Time', theme),
                const SizedBox(width: 6),
                _buildPosDateChip('Today', theme),
                const SizedBox(width: 6),
                _buildPosDateChip('Yesterday', theme),
                const SizedBox(width: 6),
                _buildPosDateChip('This Week', theme),
                const SizedBox(width: 6),
                _buildPosDateChip('This Month', theme),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 13),
                  label: Text(
                    _historyCustomRange != null
                        ? '${DateFormat('d MMM').format(_historyCustomRange!.start)} - ${DateFormat('d MMM').format(_historyCustomRange!.end)}'
                        : 'Custom Range',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _historyDateFilter == 'Custom Range' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  backgroundColor: _historyDateFilter == 'Custom Range'
                      ? const Color(0xFF1565C0).withValues(alpha: 0.15)
                      : null,
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _historyCustomRange ??
                          DateTimeRange(
                            start: DateTime.now().subtract(const Duration(days: 7)),
                            end: DateTime.now(),
                          ),
                    );
                    if (picked != null) {
                      setState(() {
                        _historyDateFilter = 'Custom Range';
                        _historyCustomRange = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),

          // Records List or Empty State
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No shaving or haircut records found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text('Try adjusting your search query, barber filter, or date range.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset All Filters'),
                          onPressed: () {
                            setState(() {
                              _historySearchController.clear();
                              _historyBarberFilter = 'All';
                              _historyServiceFilter = 'All';
                              _historyDateFilter = 'All Time';
                              _historyCustomRange = null;
                            });
                          },
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, sepIndex) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      return _buildPosRecordCard(record, salesHistory, theme);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosDateChip(String label, ThemeData theme) {
    final isSelected = _historyDateFilter == label;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF1565C0),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade400,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _historyDateFilter = label;
            _historyCustomRange = null;
          });
        }
      },
    );
  }

  Widget _buildPosRecordCard(BarberRecord record, List<SaleRecord> sales, ThemeData theme) {
    final isShave = record.serviceCategory == 'Shaves & Beard';
    final isDye = record.serviceCategory == 'Dye & Color';
    final isFacial = record.serviceCategory == 'Facials & Wash';
    final isKid = record.serviceCategory == 'Kids Haircut';

    Color categoryColor = const Color(0xFF1565C0);
    IconData categoryIcon = Icons.cut;
    if (isShave) {
      categoryColor = const Color(0xFFD32F2F);
      categoryIcon = Icons.face_retouching_natural;
    } else if (isDye) {
      categoryColor = const Color(0xFF6A1B9A);
      categoryIcon = Icons.palette;
    } else if (isFacial) {
      categoryColor = Colors.teal;
      categoryIcon = Icons.clean_hands;
    } else if (isKid) {
      categoryColor = Colors.orange.shade800;
      categoryIcon = Icons.child_care;
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.12),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              record.serviceCategory,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Haircut / Service: ${record.service}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_pin, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('Barber: ${record.barber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 10),
                          if (record.customerPhone.isNotEmpty) ...[
                            const Icon(Icons.phone, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(record.customerPhone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(record.totalPaid),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('EEE, d MMM yyyy @ h:mm a').format(record.timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Via ${record.source}',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Fixed Comm: ₵${record.effectiveCommission.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (record.tip > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Tip: ₵${record.tip.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 9, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    if (record.saleId != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 10),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.receipt_long, size: 12),
                        label: const Text('Receipt'),
                        onPressed: () {
                          final matched = sales.where((s) => s.id == record.saleId).firstOrNull;
                          if (matched != null) {
                            ReceiptService.printReceipt(matched, context: context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invoice #${record.saleId} recorded.')),
                            );
                          }
                        },
                      ),
                    if (record.customerPhone.isNotEmpty)
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF1565C0)),
                        tooltip: 'Send Follow-up SMS',
                        onPressed: () async {
                          await SmsService.sendPostHaircutSms(
                            name: record.customerName,
                            phone: record.customerPhone,
                            serviceName: record.service,
                            barberName: record.barber,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Follow-up SMS sent to ${record.customerPhone}.')),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

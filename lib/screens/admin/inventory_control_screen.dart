import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../services/product_service.dart';
import '../../models/product.dart';
import '../../core/uuid_utils.dart';
import '../../core/utils.dart';
import 'package:intl/intl.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/transfer_provider.dart';
import '../../widgets/passcode_guard.dart';

import '../../services/product_seeder.dart';

import '../../widgets/role_pop_scope.dart';

class InventoryControlScreen extends ConsumerStatefulWidget {
  const InventoryControlScreen({super.key});

  @override
  ConsumerState<InventoryControlScreen> createState() => _InventoryControlScreenState();
}

class _InventoryControlScreenState extends ConsumerState<InventoryControlScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSector = 'pharmacy'; // 'pharmacy', 'phones', 'all'

  String _getSector(Product p) {
    final cat = p.category.toUpperCase();
    if (p.requiresPrescription ||
        cat.contains('PHARM') ||
        cat.contains('DRUG') ||
        cat.contains('MED') ||
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
        cat.contains('SEDATIVE')) {
      return 'pharmacy';
    }
    return 'phones';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final activeRole = user.activePrimaryRole;
    final isAdmin = activeRole == UserRole.admin || activeRole == UserRole.superAdmin;

    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsFutureProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/stock';

    // Safety: Reset selected category if it no longer exists after deletions
    if (productsAsync.hasValue) {
      final products = productsAsync.value!;
      final availableCategories = ['All', ...products.where((p) => !p.isDeleted).where((p) => _selectedSector == 'all' || _getSector(p) == _selectedSector).map((p) => _normalizeCategory(p)).toSet()];
      if (!availableCategories.contains(_selectedCategory)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategory = 'All');
        });
      }
    }

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const MainAppBar(title: 'Inventory Control', showMenuButton: true),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: AppSidebar(
                    userId: user.id,
                    userName: user.name,
                    userRole: user.activePrimaryRole.name.toUpperCase(),
                    currentRoute: currentRoute,
                    items: MenuService.getMenuItemsForUser(user),
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
                  items: MenuService.getMenuItemsForUser(user),
                  onTap: (route) => MenuService.navigate(context, route, currentRoute),
                ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, ref, productsAsync.value ?? [], isAdmin: isAdmin),
                        const SizedBox(height: AppSpacing.m),
                        _buildSectorTabBar(theme, productsAsync.value ?? []),
                        const SizedBox(height: AppSpacing.m),
                        _buildSectorSummaryCards(theme, productsAsync.value ?? []),
                        const SizedBox(height: AppSpacing.m),
                        _buildFilters(theme, productsAsync.value ?? []),
                        const SizedBox(height: AppSpacing.l),
                        productsAsync.when(
                          data: (products) {
                            final activeProducts = products
                                .where((p) => !p.isDeleted)
                                .where((p) {
                                  if (_selectedSector == 'all') return true;
                                  return _getSector(p) == _selectedSector;
                                })
                                .where((p) {
                                  final normCat = _normalizeCategory(p);
                                  return _selectedCategory == 'All' || normCat == _selectedCategory;
                                })
                                .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                               p.category.toLowerCase().contains(_searchQuery.toLowerCase()))
                                .toList();

                            // Sort: Priced products and higher quantity first
                            activeProducts.sort((a, b) {
                              // 1. Priced products (price > 0) come first
                              final bool aPriced = a.retailPrice > 0;
                              final bool bPriced = b.retailPrice > 0;
                              if (aPriced != bPriced) return aPriced ? -1 : 1;
                              
                              // 2. Products with higher quantity come first
                              return b.stockQuantity.compareTo(a.stockQuantity);
                            });
                            
                            if (activeProducts.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 48, color: theme.disabledColor),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty 
                                          ? 'No products found matching "$_searchQuery"'
                                          : (user.branchCode == null 
                                              ? 'The global catalog is currently empty.' 
                                              : 'No products found for this branch.'),
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_searchQuery.isEmpty && isAdmin) ...[
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: () => _showAddProductDialog(context, ref),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Your First Product'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return _buildProductGrid(context, activeProducts, ref, isAdmin: isAdmin);
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Error: $err')),
                        ),
                        // Add padding for bottom navigation bars
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isAdmin ? SafeArea(
            child: FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context, ref),
              backgroundColor: _selectedSector == 'pharmacy'
                  ? const Color(0xFF2E7D32)
                  : (_selectedSector == 'phones'
                      ? const Color(0xFFE65100)
                      : theme.colorScheme.primary),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ) : null,
        ),
      ),
    );
  }

  Widget _buildSectorTabBar(ThemeData theme, List<Product> allProducts) {
    final activeProducts = allProducts.where((p) => !p.isDeleted).toList();
    final pharmacyCount = activeProducts.where((p) => _getSector(p) == 'pharmacy').length;
    final phonesCount = activeProducts.where((p) => _getSector(p) == 'phones').length;
    final totalCount = activeProducts.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: theme.dividerColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectorPill('pharmacy', 'Pharmacy Stock', Icons.medical_services_outlined, const Color(0xFF2E7D32), pharmacyCount),
            const SizedBox(width: 6),
            _sectorPill('phones', 'Phones & Accessories Stock', Icons.phone_android_outlined, const Color(0xFFE65100), phonesCount),
            const SizedBox(width: 6),
            _sectorPill('all', 'All Inventory', Icons.inventory_2_outlined, Colors.blue.shade800, totalCount),
          ],
        ),
      ),
    );
  }

  Widget _sectorPill(String id, String label, IconData icon, Color color, int count) {
    final isSelected = _selectedSector == id;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSector = id;
          _selectedCategory = 'All'; // Reset category filter on sector change
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorSummaryCards(ThemeData theme, List<Product> allProducts) {
    final activeProducts = allProducts.where((p) => !p.isDeleted).toList();
    final sectorProducts = activeProducts.where((p) => _selectedSector == 'all' || _getSector(p) == _selectedSector).toList();
    
    final int totalCount = sectorProducts.length;
    final int lowStockCount = sectorProducts.where((p) => !p.isUnlimited && p.stockQuantity <= p.lowStockThreshold).length;
    final double totalValue = sectorProducts.fold(0.0, (sum, p) => sum + (p.stockQuantity * p.retailPrice));

    String specialLabel = 'Rx Required';
    String specialValue = '${sectorProducts.where((p) => p.requiresPrescription).length}';
    IconData specialIcon = Icons.healing_outlined;
    Color specialColor = Colors.red;

    if (_selectedSector == 'phones') {
      specialLabel = 'IMEI Registered';
      specialValue = '${sectorProducts.where((p) => p.requiresImei).length}';
      specialIcon = Icons.qr_code_outlined;
      specialColor = Colors.deepOrange;
    } else if (_selectedSector == 'all') {
      specialLabel = 'Total Categories';
      specialValue = '${sectorProducts.map((p) => _normalizeCategory(p)).toSet().length}';
      specialIcon = Icons.category_outlined;
      specialColor = Colors.purple;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        child: Wrap(
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.m,
          children: [
            _statCard(theme, 'Total SKUs', '$totalCount', Icons.inventory_2_outlined, theme.colorScheme.primary, isMobile),
            _statCard(theme, 'Low Stock Alerts', '$lowStockCount', Icons.warning_amber_rounded, Colors.orange.shade800, isMobile),
            _statCard(theme, specialLabel, specialValue, specialIcon, specialColor, isMobile),
            _statCard(theme, 'Stock Valuation', 'GHS ${totalValue.toStringAsFixed(2)}', Icons.payments_outlined, Colors.green.shade800, isMobile),
          ],
        ),
      );
    });
  }

  Widget _statCard(ThemeData theme, String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 210,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.s),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, List<Product> products) {
    final activeSectorProducts = products
        .where((p) => !p.isDeleted)
        .where((p) => _selectedSector == 'all' || _getSector(p) == _selectedSector)
        .toList();

    final categories = ['All', ...activeSectorProducts.map((p) => _normalizeCategory(p)).toSet()];
    final isMobile = ResponsiveLayout.isMobile(context);

    return Wrap(
      spacing: AppSpacing.m,
      runSpacing: AppSpacing.m,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : 400,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or category...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
                : null,
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
          ),
        ),
        SizedBox(
          width: isMobile ? double.infinity : 200,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
            decoration: InputDecoration(
              labelText: 'Sort Category',
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            ),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<Product> products, {required bool isAdmin}) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final pendingTransfers = ref.watch(pendingIncomingTransfersProvider);

    final actionButtons = [
      if (pendingTransfers.isNotEmpty)
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/cashier/verify-stock'),
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: Text('Verify Incoming (${pendingTransfers.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
          ),
        ),
      if (isAdmin) ...[
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'unlimited') {
              _showBulkUnlimitedDialog(context, ref, products, true);
            } else if (val == 'fixed') {
              _showBulkUnlimitedDialog(context, ref, products, false);
            }
          },
          child: OutlinedButton.icon(
            onPressed: null, // Let PopupMenuButton handle it
            icon: const Icon(Icons.settings_suggest_outlined, size: 18),
            label: const Text('Bulk Actions', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'unlimited',
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Set ALL to Unlimited'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'fixed',
              child: Row(
                children: [
                  Icon(Icons.pin, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Set ALL to Fixed Qty'),
                ],
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => _showPromotionDialog(context, ref, products),
          icon: const Icon(Icons.campaign_outlined, size: 18),
          label: const Text('Promotions', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade800),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin/product-report'),
          icon: const Icon(Icons.assessment_outlined, size: 18),
          label: const Text('Activity Report', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Initialize Catalog?'),
                content: const Text('This will seed the standard multi-business product catalog (Pharmacy, Barber, Phone & Accessories) with 0.0 quantity if they don\'t exist. Continue?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('INITIALIZE')),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(productSeederProvider).seedProducts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalog initialized successfully!')));
              }
            }
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Load Defaults', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ]
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Master Stock List', 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text('Manage products, pricing, and stock levels', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (actionButtons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actionButtons,
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Master Stock List', 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text('Manage products, pricing, and stock levels', 
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        if (actionButtons.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actionButtons,
          ),
      ],
    );
  }

  void _showBulkUnlimitedDialog(BuildContext context, WidgetRef ref, List<Product> products, bool isUnlimited) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUnlimited ? 'Set All to Unlimited?' : 'Set All to Fixed Qty?'),
        content: Text(isUnlimited 
          ? 'This will make every product in the catalog "Unlimited", meaning sales will not decrease the current stock levels. Continue?'
          : 'This will make every product follow "Fixed" stock, where sales will subtract from the defined quantity. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(productsFutureProvider.notifier).setUnlimitedStatus(isUnlimited);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All products updated to ${isUnlimited ? "Unlimited" : "Fixed"} stock.'))
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: isUnlimited ? Colors.blue : Colors.green, foregroundColor: Colors.white),
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  void _showPromotionDialog(BuildContext context, WidgetRef ref, List<Product> products, {Product? initialProduct}) {
    final formKey = GlobalKey<FormState>();
    final percentageController = TextEditingController(
      text: initialProduct != null 
        ? (initialProduct.discountPercentage % 1 == 0 
            ? initialProduct.discountPercentage.toInt().toString() 
            : initialProduct.discountPercentage.toString())
        : ''
    );
    final theme = Theme.of(context);
    DateTime? startDate = initialProduct?.promoStartDate;
    DateTime? endDate = initialProduct?.promoEndDate;
    PromoTarget selectedTarget = initialProduct?.promoTarget ?? PromoTarget.both;
    PromoCustomerTarget selectedCustomerTarget = initialProduct?.promoCustomerTarget ?? PromoCustomerTarget.all;
    
    final selectedIds = <String>{};
    if (initialProduct != null) {
      selectedIds.add(initialProduct.id);
    } else {
      for (var p in products) {
        selectedIds.add(p.id);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final allSelected = selectedIds.length == products.length;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            title: Row(
              children: [
                const Icon(Icons.campaign_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Text('Run Promotion', style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      TextFormField(
                        controller: percentageController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Percentage (%)',
                          hintText: 'e.g. 10 or 12.5',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0 || n > 100) return 'Invalid % (0.1 - 100)';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<PromoTarget>(
                        initialValue: selectedTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Promotion Target'),
                        items: const [
                          DropdownMenuItem(value: PromoTarget.both, child: Text('Both Retail & Wholesale', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoTarget.retail, child: Text('Retail Only', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoTarget.wholesale, child: Text('Wholesale Only', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => selectedTarget = v!),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<PromoCustomerTarget>(
                        initialValue: selectedCustomerTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Customer Eligibility'),
                        items: const [
                          DropdownMenuItem(value: PromoCustomerTarget.all, child: Text('All Customers (Public)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoCustomerTarget.regularsOnly, child: Text('Regulars/Favorites Only', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => selectedCustomerTarget = v!),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: (startDate != null && endDate != null) 
                              ? DateTimeRange(start: startDate!, end: endDate!)
                              : DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 7))),
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked.start;
                              endDate = picked.end;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: startDate == null ? Colors.grey : theme.colorScheme.primary),
                            borderRadius: BorderRadius.circular(AppRadius.s),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  startDate == null 
                                    ? 'Select Promotion Dates (Required)' 
                                    : '${DateFormat('MMM dd').format(startDate!)} - ${DateFormat('MMM dd').format(endDate!)}',
                                  style: TextStyle(
                                    color: startDate == null ? Colors.grey : theme.colorScheme.onSurface,
                                    fontWeight: startDate == null ? FontWeight.normal : FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      const Divider(),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Select Products:', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (allSelected) {
                                  selectedIds.clear();
                                } else {
                                  selectedIds.addAll(products.map((p) => p.id));
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(allSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                        child: ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return CheckboxListTile(
                              title: Text('${p.category} - ${p.name}', style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('Current: ₵${p.retailPrice}', style: const TextStyle(fontSize: 10)),
                              value: selectedIds.contains(p.id),
                              onChanged: (val) {
                                setState(() {
                                  if (val!) {
                                    selectedIds.add(p.id);
                                  } else {
                                    selectedIds.remove(p.id);
                                  }
                                });
                              },
                              dense: true,
                              activeColor: theme.colorScheme.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actionsOverflowButtonSpacing: 8,
          actionsAlignment: MainAxisAlignment.end,
          actions: [
              TextButton(
                onPressed: () {
                  ref.read(productsFutureProvider.notifier).clearPromotions();
                  Navigator.pop(context);
                },
                child: const Text('Clear All Promos', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: (selectedIds.isEmpty || startDate == null || endDate == null) ? null : () {
                  if (formKey.currentState!.validate()) {
                    final percentage = double.tryParse(percentageController.text) ?? 0;
                    ref.read(productsFutureProvider.notifier).applyPromotion(
                      percentage, 
                      startDate!, 
                      endDate!, 
                      selectedTarget,
                      selectedCustomerTarget,
                      selectedIds: selectedIds.toList()
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text('Apply to ${selectedIds.length} Items', style: const TextStyle(fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getUnitLabel(String u) {
    final unit = u.toLowerCase();
    if (unit == 'tablets') return 'Tablets/Pack';
    if (unit == 'capsules') return 'Capsules/Pack';
    if (unit == 'mils') return 'Mils/Unit';
    if (unit == 'bottles') return 'Units/Bottle';
    if (unit == 'packs') return 'Units/Pack';
    if (unit == 'boxes') return 'Units/Box';
    return 'Pcs/Pack';
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final products = ref.read(productsFutureProvider).value ?? [];
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final retailPriceController = TextEditingController();
    final wholesalePriceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController();
    final otherCategoryController = TextEditingController();
    final customNameController = TextEditingController();
    final theme = Theme.of(context);

    final batchNumberController = TextEditingController();
    final imeiController = TextEditingController();
    final boxesController = TextEditingController(text: '1');
    final packsPerBoxController = TextEditingController(text: '10');
    final piecesPerPackController = TextEditingController(text: '10');
    final packPriceController = TextEditingController();
    final boxPriceController = TextEditingController();
    bool isPackPriceOverridden = false;
    bool isBoxPriceOverridden = false;
    bool isTabletPriceOverridden = false;

    bool isUpdatingPrices = false;

    void recalculatePharmacyValues({String source = 'boxes'}) {
      if (isUpdatingPrices) return;
      isUpdatingPrices = true;

      final boxes = double.tryParse(boxesController.text) ?? 0.0;
      final packsPerBox = double.tryParse(packsPerBoxController.text) ?? 1.0;
      final piecesPerPack = double.tryParse(piecesPerPackController.text) ?? 1.0;

      final totalPieces = boxes * packsPerBox * piecesPerPack;
      stockController.text = totalPieces % 1 == 0 ? totalPieces.toInt().toString() : totalPieces.toStringAsFixed(1);

      double tabletPrice = double.tryParse(retailPriceController.text) ?? 0.0;
      double packPrice = double.tryParse(packPriceController.text) ?? 0.0;
      double boxPrice = double.tryParse(boxPriceController.text) ?? 0.0;

      if (source == 'tablet') {
        if (!isPackPriceOverridden) {
          packPrice = tabletPrice * piecesPerPack;
          packPriceController.text = packPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      } else if (source == 'pack') {
        if (piecesPerPack > 0 && !isTabletPriceOverridden) {
          tabletPrice = packPrice / piecesPerPack;
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      } else if (source == 'box') {
        if (packsPerBox > 0 && !isPackPriceOverridden) {
          packPrice = boxPrice / packsPerBox;
          packPriceController.text = packPrice.toStringAsFixed(2);
        }
        if (piecesPerPack > 0 && packsPerBox > 0 && !isTabletPriceOverridden) {
          tabletPrice = boxPrice / (packsPerBox * piecesPerPack);
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
      } else {
        if (tabletPrice > 0 && !isPackPriceOverridden) {
          packPrice = tabletPrice * piecesPerPack;
          packPriceController.text = packPrice.toStringAsFixed(2);
        } else if (packPrice > 0 && !isTabletPriceOverridden) {
          tabletPrice = packPrice / piecesPerPack;
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      }

      isUpdatingPrices = false;
    }
    DateTime? selectedExpiryDate;
    bool requiresPrescription = _selectedSector == 'pharmacy';
    bool requiresImei = _selectedSector == 'phones';
    bool isService = false;

    String selectedCategory;
    String? selectedProductName;
    WeightUnit selectedUnit = WeightUnit.unit;
    String selectedPharmacyUnit = 'tablets';
    bool isUnlimited = false;

    final Map<String, List<String>> categoryProductMap = {
      // Pharmacy Presets
      'Antimalarial': ['Antfan Tab', 'Lufant DS', 'Artfan Suspension', 'Lufart suspension', 'Other'],
      'Antibiotic': ['Amoxicillin caps', 'Ciprofloxacin', 'Azithromycin', 'Cefuroxime', 'Norfloxacin 200mg', 'Chloramphenicol', 'Metronidazole sirop', 'Other'],
      'Analgesic': ['Peladol extra', 'ESKcol', 'Eskadol nyte', 'Drastin APC', 'Parabary tab', 'Other'],
      'NSAID': ['Basecam', 'Cap celecoxib 200mg', 'Prednisolone', 'Other'],
      'Cough & Cold': ['Coldrs... caps', 'Kwik action', 'Shaltoux', 'Ronak Inhaler', 'Other'],
      'Cardiovascular': ['Skydipin 30', 'Losartan 50', 'Losartan Potassium', 'Other'],
      'Gastrointestinal': ['Magnesium trisilicate sup', 'Magacid susp.', 'Zerocid susp.', 'Liver salt', 'Other'],
      'Contraceptive': ['Lydia Secure', 'Contra-72', 'Postinor 2', 'Kiss condom', 'Other'],
      'Supplement': ['GML-Apeti', 'Riddles Mud Syrup', 'Ayrton mult. Syrup', 'Dynoell Syrup', 'Haemoglobin sirop', 'Eppace Junior Syrp', 'Polyfer forte syrup', 'Samalin adult sirop', 'Samalin junior', 'Tres-orix', 'Cyfen syrup', 'Bricovit forte', 'Lechna syrup', 'Cehtone syrup', 'Cyproidine', 'Abytone forte caps', 'Other'],
      'Topical & Gel': ['Ronfit Gel', 'Ronfit forte', 'Other'],
      'Sedative': ['Chlordiazepoxide', 'Other'],
      'General Medication': ['Zudrex tab', 'Letacam', 'Mixtel', 'Fembase extra', 'Asmanol', 'Tracaram', 'Cibro-C', 'Pecbore', 'Ronloz 100', 'Treedar', 'Let-2in simp', 'Other'],

      // Phones & Accessories Presets
      'Smartphones': ['iPhone 15 Pro 128GB', 'Samsung Galaxy S24 Ultra', 'Google Pixel 8 Pro', 'Xiaomi Redmi Note 13 Pro', 'Tecno Camon 30 Premier', 'Other'],
      'Chargers & Power': ['20W USB-C Fast Charger', '65W GaN Desktop Fast Charger', '20,000mAh Power Bank (22.5W)', '15W MagSafe Wireless Pad', 'Type-C to Lightning Cable 1m', '100W Braided Type-C Cable', 'Other'],
      'Cases & Protection': ['MagSafe Clear Case', 'Shockproof Silicone Armor Case', 'Leather Flip Wallet Case', 'Other'],
      'Screen Protectors': ['9D Curved Tempered Glass', 'Anti-Spy Privacy Tempered Glass', 'HD Camera Lens Protector', 'Other'],
      'Audio & Sound': ['Wireless ANC Noise Cancelling Earbuds', 'AirPods Pro 2nd Gen', 'Sports Bluetooth Neckband', 'Portable Mini Bluetooth Speaker', 'Other'],
      'Smart Wearables': ['Smartwatch Series 9 (AMOLED)', 'Fitness Tracker Band 8', 'Other'],
      'Mounts & Holders': ['Magnetic Car Air Vent Mount', 'Adjustable Desktop Phone Stand', 'Other'],
      'Repairs & Services': ['iPhone Screen Repair (Labor + Part)', 'Battery Replacement Service', 'Charging Port Repair', 'Software Flashing & Unlocking', 'Other'],

      'Other': ['Custom Entry']
    };

    final List<String> categories;
    if (_selectedSector == 'pharmacy') {
      final pharmacyPresetCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
      ];
      final existingPharmacyCats = products
          .where((p) => _getSector(p) == 'pharmacy')
          .map((p) => _normalizeCategory(p))
          .toSet();
      categories = [...{...pharmacyPresetCategories, ...existingPharmacyCats}, 'Other'];
      selectedCategory = categories.first;
    } else if (_selectedSector == 'phones') {
      final phonePresetCategories = [
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
      ];
      final existingPhoneCats = products
          .where((p) => _getSector(p) == 'phones')
          .map((p) => _normalizeCategory(p))
          .toSet();
      categories = [...{...phonePresetCategories, ...existingPhoneCats}, 'Other'];
      selectedCategory = categories.first;
    } else {
      final allCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
      ];
      final existingCats = products.map((p) => _normalizeCategory(p)).toSet();
      categories = [...{...allCategories, ...existingCats}, 'Other'];
      selectedCategory = categories.first;
    }

    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isPharmacySection = _selectedSector == 'pharmacy' ||
              ['Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold', 'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement', 'Topical & Gel', 'Sedative', 'General Medication'].contains(selectedCategory) ||
              selectedCategory.toUpperCase().contains('PHARM') ||
              selectedCategory.toUpperCase().contains('DRUG') ||
              selectedCategory.toUpperCase().contains('MED');

          final isPhoneSection = _selectedSector == 'phones' ||
              ['Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors', 'Audio & Sound', 'Smart Wearables', 'Mounts & Holders'].contains(selectedCategory) ||
              selectedCategory.toUpperCase().contains('PHONE') ||
              selectedCategory.toUpperCase().contains('SMART') ||
              selectedCategory.toUpperCase().contains('ACCESSOR') ||
              selectedCategory.toUpperCase().contains('MOBILE');

          final isRepairSection = selectedCategory == 'Repairs & Services' ||
              selectedCategory.toUpperCase().contains('REPAIR') ||
              selectedCategory.toUpperCase().contains('SERVICE');

          final Color sectorColor = _selectedSector == 'pharmacy'
              ? const Color(0xFF2E7D32)
              : (_selectedSector == 'phones'
                  ? const Color(0xFFE65100)
                  : theme.colorScheme.primary);

          return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: sectorColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Enter product details for the shop catalog', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(AppSpacing.l),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setState(() {
                          imageBytes = bytes;
                          imageName = image.name;
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.m),
                              child: Image.memory(imageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 4),
                                Text('Add Image', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() {
                    selectedCategory = v!;
                    selectedProductName = null;
                    nameController.clear();
                  }),
                ),
                if (selectedCategory == 'Other') ...[
                  const SizedBox(height: AppSpacing.m),
                  _buildFormTextField(
                    context: context,
                    controller: otherCategoryController,
                    label: 'Custom Category Name',
                    hint: 'e.g. Special Tech',
                    icon: Icons.edit_note,
                    isName: true,
                    validator: (v) => (selectedCategory == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedProductName,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  items: (categoryProductMap[selectedCategory] ?? (products.where((p) => p.category == selectedCategory).map((p) => p.name).toSet().toList()..add('Other'))).map((name) {
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() {
                    selectedProductName = v;
                    if (v != 'Other' && v != 'Custom Entry') {
                      nameController.text = v!;
                    } else {
                      nameController.clear();
                    }
                  }),
                  validator: (v) => (v == null) ? 'Required' : null,
                ),
                if (selectedProductName == 'Other' || selectedProductName == 'Custom Entry') ...[
                  const SizedBox(height: AppSpacing.m),
                  _buildFormTextField(
                    context: context,
                    controller: customNameController,
                    label: 'Custom Product Name',
                    hint: 'e.g. Product Item Name',
                    icon: Icons.edit_note,
                    isName: true,
                    onChanged: (v) => nameController.text = v,
                    validator: (v) => ((selectedProductName == 'Other' || selectedProductName == 'Custom Entry') && (v == null || v.isEmpty)) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormTextField(
                        context: context,
                        controller: retailPriceController,
                        label: 'Retail',
                        prefix: '₵ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () {
                          if (retailPriceController.text == '0.0' || retailPriceController.text == '0') {
                            retailPriceController.clear();
                          }
                        },
                        onChanged: (v) {
                          isTabletPriceOverridden = true;
                          recalculatePharmacyValues(source: 'tablet');
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _buildFormTextField(
                        context: context,
                        controller: wholesalePriceController,
                        label: 'Wholesale',
                        prefix: '₵ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () {
                          if (wholesalePriceController.text == '0.0' || wholesalePriceController.text == '0') {
                            wholesalePriceController.clear();
                          }
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _buildFormTextField(
                        context: context,
                        controller: costPriceController,
                        label: 'Cost',
                        prefix: '₵ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () {
                          if (costPriceController.text == '0.0' || costPriceController.text == '0') {
                            costPriceController.clear();
                          }
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormTextField(
                        context: context,
                        controller: stockController,
                        label: isUnlimited ? 'Current Quantity (Display only)' : 'Initial Stock',
                        suffix: isPharmacySection ? selectedPharmacyUnit : selectedUnit.name,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (isUnlimited) return null;
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid qty';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: isPharmacySection
                          ? DropdownButtonFormField<String>(
                              initialValue: selectedPharmacyUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              items: ['tablets', 'capsules', 'pcs', 'mils', 'bottles', 'packs', 'boxes']
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase())))
                                  .toList(),
                              onChanged: (v) => setState(() => selectedPharmacyUnit = v!),
                            )
                          : DropdownButtonFormField<WeightUnit>(
                              initialValue: selectedUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              items: WeightUnit.values.map((u) => DropdownMenuItem(value: u, child: Text(u == WeightUnit.unit ? 'PCS' : u.name.toUpperCase()))).toList(),
                              onChanged: (v) => setState(() => selectedUnit = v!),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                SwitchListTile(
                  title: const Text('Unlimited Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sales will not subtract from quantity', style: TextStyle(fontSize: 11)),
                  value: isUnlimited, 
                  onChanged: (v) => setState(() => isUnlimited = v),
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),

                if (isPharmacySection) ...[
                  const SizedBox(height: AppSpacing.m),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medication_liquid_outlined, size: 18, color: Color(0xFF2E7D32)),
                            SizedBox(width: 6),
                            Text('Boxes, Packs & ${selectedPharmacyUnit.toUpperCase()} Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Enter boxes, packs per box & $selectedPharmacyUnit per pack to calculate stock & pricing', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormTextField(
                                context: context,
                                controller: boxesController,
                                label: 'Boxes',
                                hint: 'e.g. 2',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) => recalculatePharmacyValues(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: _buildFormTextField(
                                context: context,
                                controller: packsPerBoxController,
                                label: 'Packs/Box',
                                hint: 'e.g. 10',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) => recalculatePharmacyValues(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: _buildFormTextField(
                                context: context,
                                controller: piecesPerPackController,
                                label: _getUnitLabel(selectedPharmacyUnit),
                                hint: 'e.g. 10',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) => recalculatePharmacyValues(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormTextField(
                                context: context,
                                controller: packPriceController,
                                label: 'Price per Pack',
                                prefix: '₵ ',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) {
                                  isPackPriceOverridden = true;
                                  recalculatePharmacyValues(source: 'pack');
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Expanded(
                              child: _buildFormTextField(
                                context: context,
                                controller: boxPriceController,
                                label: 'Price per Box',
                                prefix: '₵ ',
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (v) {
                                  isBoxPriceOverridden = true;
                                  recalculatePharmacyValues(source: 'box');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _buildFormTextField(
                    context: context,
                    controller: batchNumberController,
                    label: 'Batch Number (Optional)',
                    hint: 'e.g. BATCH-2026-001',
                    icon: Icons.numbers_outlined,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => selectedExpiryDate = picked);
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedExpiryDate == null 
                                  ? 'Batch Expiry Date (Optional)' 
                                  : 'Expiry: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: selectedExpiryDate == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (selectedExpiryDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => selectedExpiryDate = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    title: const Text('Requires Doctor Prescription (Rx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: requiresPrescription,
                    onChanged: (v) => setState(() => requiresPrescription = v),
                    activeThumbColor: Colors.red,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],

                if (isPhoneSection) ...[
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    title: const Text('Track Serial / IMEI Numbers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Enables individual IMEI tracking per unit', style: TextStyle(fontSize: 11)),
                    value: requiresImei,
                    onChanged: (v) => setState(() => requiresImei = v),
                    activeThumbColor: Colors.blue,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (requiresImei) ...[
                    const SizedBox(height: AppSpacing.m),
                    _buildFormTextField(
                      context: context,
                      controller: imeiController,
                      label: 'IMEI Numbers (Comma or Newline Separated)',
                      hint: 'e.g. 356789123456789, 864210987654321',
                      icon: Icons.qr_code,
                      keyboardType: TextInputType.multiline,
                      onChanged: (v) {
                        final count = v.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).length;
                        if (count > 0) {
                          stockController.text = count.toString();
                        }
                      },
                    ),
                  ],
                ],

                if (isRepairSection) ...[
                  const SizedBox(height: AppSpacing.m),
                  SwitchListTile(
                    title: const Text('Is Service / Labor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('No physical inventory is subtracted on sale', style: TextStyle(fontSize: 11)),
                    value: isService,
                    onChanged: (v) => setState(() {
                      isService = v;
                      if (v) isUnlimited = true;
                    }),
                    activeThumbColor: Colors.purple,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isUploading = true);
                  
                  String finalImageUrl = '';
                  
                  if (imageBytes != null && imageName != null) {
                    final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                      imageBytes!, 
                      'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                    );
                    if (uploadedUrl != null) {
                      finalImageUrl = uploadedUrl;
                    }
                  }

                  String finalName = nameController.text;

                  final String validUuid = UuidUtils.generate();

                  List<String>? imeis;
                  if (imeiController.text.trim().isNotEmpty) {
                    imeis = imeiController.text
                        .split(RegExp(r'[,\n]'))
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                  }

                  final double? boxesCount = isPharmacySection ? double.tryParse(boxesController.text) : null;
                  final double? packsPerBox = isPharmacySection ? double.tryParse(packsPerBoxController.text) : null;
                  final double? piecesPerPack = isPharmacySection ? double.tryParse(piecesPerPackController.text) : null;
                  final double? packPrice = isPharmacySection ? double.tryParse(packPriceController.text) : null;
                  final double? boxPrice = isPharmacySection ? double.tryParse(boxPriceController.text) : null;

                  final newProduct = Product(
                    id: validUuid,
                    name: finalName,
                    retailPrice: double.tryParse(retailPriceController.text) ?? 0.0,
                    wholesalePrice: (isPharmacySection && packPrice != null) ? packPrice : (double.tryParse(wholesalePriceController.text) ?? 0.0),
                    costPrice: double.tryParse(costPriceController.text) ?? 0.0,
                    category: selectedCategory == 'Other' ? otherCategoryController.text : selectedCategory,
                    imageUrl: finalImageUrl,
                    stockQuantity: (requiresImei && imeis != null && imeis.isNotEmpty) 
                        ? imeis.length.toDouble() 
                        : (double.tryParse(stockController.text) ?? 0.0),
                    unit: isPharmacySection ? selectedPharmacyUnit : selectedUnit.name,
                    isUnlimited: isUnlimited || isService,
                    batchNumber: batchNumberController.text.trim().isNotEmpty ? batchNumberController.text.trim() : null,
                    batchExpiryDate: selectedExpiryDate,
                    requiresPrescription: requiresPrescription,
                    requiresImei: requiresImei,
                    numberOfBoxes: boxesCount,
                    packsPerBox: packsPerBox,
                    boxPrice: boxPrice,
                    piecesPerPack: piecesPerPack,
                    packPrice: packPrice,
                    imeiList: imeis,
                    isService: isService,
                  );
                  await ref.read(productsFutureProvider.notifier).addProduct(newProduct);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: sectorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              ),
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Add Product'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final retailPriceController = TextEditingController(text: product.retailPrice.toString());
    final wholesalePriceController = TextEditingController(text: product.wholesalePrice.toString());
    final costPriceController = TextEditingController(text: product.costPrice.toString());
    final stockController = TextEditingController(text: product.stockQuantity.toString());
    final otherCategoryController = TextEditingController();
    final batchNumberController = TextEditingController(text: product.batchNumber ?? '');
    final imeiController = TextEditingController(text: product.imeiList?.join(', ') ?? '');
    final double initialPcsPerPack = (product.piecesPerPack != null && product.piecesPerPack! > 0) ? product.piecesPerPack! : 10.0;
    final double initialPacksPerBox = (product.packsPerBox != null && product.packsPerBox! > 0) ? product.packsPerBox! : 10.0;
    final double initialBoxes = (product.numberOfBoxes != null && product.numberOfBoxes! > 0) 
        ? product.numberOfBoxes! 
        : (initialPacksPerBox > 0 && initialPcsPerPack > 0 ? (product.stockQuantity / (initialPacksPerBox * initialPcsPerPack)) : 1.0);
    
    final double initialPackPrice = product.packPrice ?? (product.retailPrice * initialPcsPerPack);
    final double initialBoxPrice = product.boxPrice ?? (initialPackPrice * initialPacksPerBox);

    final boxesController = TextEditingController(text: initialBoxes.toStringAsFixed(0));
    final packsPerBoxController = TextEditingController(text: initialPacksPerBox.toStringAsFixed(0));
    final piecesPerPackController = TextEditingController(text: initialPcsPerPack.toStringAsFixed(0));
    final packPriceController = TextEditingController(text: initialPackPrice.toStringAsFixed(2));
    final boxPriceController = TextEditingController(text: initialBoxPrice.toStringAsFixed(2));
    bool isPackPriceOverridden = product.packPrice != null;
    bool isBoxPriceOverridden = product.boxPrice != null;
    bool isTabletPriceOverridden = product.retailPrice > 0;

    bool isUpdatingPrices = false;

    void recalculatePharmacyValues({String source = 'boxes'}) {
      if (isUpdatingPrices) return;
      isUpdatingPrices = true;

      final boxes = double.tryParse(boxesController.text) ?? 0.0;
      final packsPerBox = double.tryParse(packsPerBoxController.text) ?? 1.0;
      final piecesPerPack = double.tryParse(piecesPerPackController.text) ?? 1.0;

      final totalPieces = boxes * packsPerBox * piecesPerPack;
      stockController.text = totalPieces % 1 == 0 ? totalPieces.toInt().toString() : totalPieces.toStringAsFixed(1);

      double tabletPrice = double.tryParse(retailPriceController.text) ?? 0.0;
      double packPrice = double.tryParse(packPriceController.text) ?? 0.0;
      double boxPrice = double.tryParse(boxPriceController.text) ?? 0.0;

      if (source == 'tablet') {
        if (!isPackPriceOverridden) {
          packPrice = tabletPrice * piecesPerPack;
          packPriceController.text = packPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      } else if (source == 'pack') {
        if (piecesPerPack > 0 && !isTabletPriceOverridden) {
          tabletPrice = packPrice / piecesPerPack;
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      } else if (source == 'box') {
        if (packsPerBox > 0 && !isPackPriceOverridden) {
          packPrice = boxPrice / packsPerBox;
          packPriceController.text = packPrice.toStringAsFixed(2);
        }
        if (piecesPerPack > 0 && packsPerBox > 0 && !isTabletPriceOverridden) {
          tabletPrice = boxPrice / (packsPerBox * piecesPerPack);
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
      } else {
        if (tabletPrice > 0 && !isPackPriceOverridden) {
          packPrice = tabletPrice * piecesPerPack;
          packPriceController.text = packPrice.toStringAsFixed(2);
        } else if (packPrice > 0 && !isTabletPriceOverridden) {
          tabletPrice = packPrice / piecesPerPack;
          retailPriceController.text = tabletPrice.toStringAsFixed(2);
        }
        if (!isBoxPriceOverridden) {
          boxPrice = packPrice * packsPerBox;
          boxPriceController.text = boxPrice.toStringAsFixed(2);
        }
      }

      isUpdatingPrices = false;
    }
    DateTime? selectedExpiryDate = product.batchExpiryDate;
    bool requiresPrescription = product.requiresPrescription;
    bool requiresImei = product.requiresImei;
    bool isService = product.isService;
    String selectedPharmacyUnit = ['tablets', 'capsules', 'pcs', 'mils', 'bottles', 'packs', 'boxes'].contains(product.unit) ? product.unit : 'tablets';
    final theme = Theme.of(context);
    
    final categories = [
      'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
      'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
      'Topical & Gel', 'Sedative', 'General Medication',
      'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
      'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
      'Other'
    ];
    String selectedCategory = categories.contains(product.category) ? product.category : 'Other';
    bool isUnlimited = product.isUnlimited;

    if (selectedCategory == 'Other') {
      otherCategoryController.text = product.category;
    }
    
    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isPharmacySection = _getSector(product) == 'pharmacy' ||
              ['Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold', 'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement', 'Topical & Gel', 'Sedative', 'General Medication'].contains(selectedCategory) ||
              selectedCategory.toUpperCase().contains('PHARM') ||
              selectedCategory.toUpperCase().contains('DRUG') ||
              selectedCategory.toUpperCase().contains('MED');

          final isPhoneSection = _getSector(product) == 'phones' ||
              ['Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors', 'Audio & Sound', 'Smart Wearables', 'Mounts & Holders'].contains(selectedCategory) ||
              selectedCategory.toUpperCase().contains('PHONE') ||
              selectedCategory.toUpperCase().contains('SMART') ||
              selectedCategory.toUpperCase().contains('ACCESSOR') ||
              selectedCategory.toUpperCase().contains('MOBILE');

          return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text('Edit Product: ${product.name}'),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setState(() {
                            imageBytes = bytes;
                            imageName = image.name;
                          });
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          child: imageBytes != null
                              ? Image.memory(imageBytes!, fit: BoxFit.cover)
                              : _buildProductImageWidget(product.imageUrl),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _buildFormTextField(
                    context: context,
                    controller: nameController, 
                    label: 'Product Name',
                    isName: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => selectedCategory = v!),
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 16),
                    _buildFormTextField(
                      context: context,
                      controller: otherCategoryController,
                      label: 'Custom Category Name',
                      isName: true,
                      validator: (v) => (selectedCategory == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: retailPriceController, 
                          label: 'Retail Price', 
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (retailPriceController.text == '0.0' || retailPriceController.text == '0') {
                              retailPriceController.clear();
                            }
                          },
                          onChanged: (v) {
                            isTabletPriceOverridden = true;
                            recalculatePharmacyValues(source: 'tablet');
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: wholesalePriceController, 
                          label: 'Wholesale Price', 
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (wholesalePriceController.text == '0.0' || wholesalePriceController.text == '0') {
                              wholesalePriceController.clear();
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: costPriceController, 
                          label: 'Cost Price', 
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (costPriceController.text == '0.0' || costPriceController.text == '0') {
                              costPriceController.clear();
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildFormTextField(
                          context: context,
                          controller: stockController,
                          label: isUnlimited ? 'Current Quantity (Display only)' : 'Stock Quantity',
                          suffix: isPharmacySection ? selectedPharmacyUnit : product.unit,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (isUnlimited) return null;
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid qty';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: isPharmacySection
                            ? DropdownButtonFormField<String>(
                                initialValue: selectedPharmacyUnit,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Unit'),
                                items: ['tablets', 'capsules', 'pcs', 'mils', 'bottles', 'packs', 'boxes']
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase())))
                                    .toList(),
                                onChanged: (v) => setState(() => selectedPharmacyUnit = v!),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Unlimited Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sales will not subtract from quantity', style: TextStyle(fontSize: 11)),
                    value: isUnlimited, 
                    onChanged: (v) => setState(() => isUnlimited = v),
                    activeThumbColor: Colors.blue,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),

                  if (isPharmacySection) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medication_liquid_outlined, size: 18, color: Color(0xFF2E7D32)),
                              SizedBox(width: 6),
                              Text('Boxes, Packs & ${selectedPharmacyUnit.toUpperCase()} Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2E7D32))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Enter boxes, packs per box & $selectedPharmacyUnit per pack to calculate stock & pricing', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: AppSpacing.m),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormTextField(
                                  context: context,
                                  controller: boxesController,
                                  label: 'Boxes',
                                  hint: 'e.g. 2',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) => recalculatePharmacyValues(),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: _buildFormTextField(
                                  context: context,
                                  controller: packsPerBoxController,
                                  label: 'Packs/Box',
                                  hint: 'e.g. 10',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) => recalculatePharmacyValues(),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: _buildFormTextField(
                                  context: context,
                                  controller: piecesPerPackController,
                                  label: _getUnitLabel(selectedPharmacyUnit),
                                  hint: 'e.g. 10',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) => recalculatePharmacyValues(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormTextField(
                                  context: context,
                                  controller: packPriceController,
                                  label: 'Price per Pack',
                                  prefix: '₵ ',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    isPackPriceOverridden = true;
                                    recalculatePharmacyValues();
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: _buildFormTextField(
                                  context: context,
                                  controller: boxPriceController,
                                  label: 'Price per Box',
                                  prefix: '₵ ',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (v) {
                                    isBoxPriceOverridden = true;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFormTextField(
                      context: context,
                      controller: batchNumberController,
                      label: 'Batch Number',
                      hint: 'e.g. BATCH-2026-001',
                      icon: Icons.numbers_outlined,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => selectedExpiryDate = picked);
                      },
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedExpiryDate == null 
                                    ? 'Batch Expiry Date (Optional)' 
                                    : 'Expiry: ${DateFormat('yyyy-MM-dd').format(selectedExpiryDate!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selectedExpiryDate == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (selectedExpiryDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => selectedExpiryDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Requires Doctor Prescription (Rx)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: requiresPrescription,
                      onChanged: (v) => setState(() => requiresPrescription = v),
                      activeThumbColor: Colors.red,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],

                  if (isPhoneSection) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Track Serial / IMEI Numbers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Enables individual IMEI tracking per unit', style: TextStyle(fontSize: 11)),
                      value: requiresImei,
                      onChanged: (v) => setState(() => requiresImei = v),
                      activeThumbColor: Colors.blue,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (requiresImei) ...[
                      const SizedBox(height: 16),
                      _buildFormTextField(
                        context: context,
                        controller: imeiController,
                        label: 'IMEI Numbers (Comma or Newline Separated)',
                        hint: 'e.g. 356789123456789, 864210987654321',
                        icon: Icons.qr_code,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ],

                  if (selectedCategory == 'Repairs & Services' || selectedCategory.toUpperCase().contains('REPAIR') || selectedCategory.toUpperCase().contains('SERVICE')) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Is Service / Labor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('No physical inventory is subtracted on sale', style: TextStyle(fontSize: 11)),
                      value: isService,
                      onChanged: (v) => setState(() {
                        isService = v;
                        if (v) isUnlimited = true;
                      }),
                      activeThumbColor: Colors.purple,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context), 
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setState(() => isUploading = true);

                  String finalImageUrl = product.imageUrl;

                  if (imageBytes != null && imageName != null) {
                    final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                      imageBytes!, 
                      'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                    );
                    if (uploadedUrl != null) {
                      finalImageUrl = uploadedUrl;
                    }
                  }

                  List<String>? imeis;
                  if (imeiController.text.trim().isNotEmpty) {
                    imeis = imeiController.text
                        .split(RegExp(r'[,\n]'))
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                  }

                  final double? boxesCount = isPharmacySection ? double.tryParse(boxesController.text) : product.numberOfBoxes;
                  final double? packsPerBox = isPharmacySection ? double.tryParse(packsPerBoxController.text) : product.packsPerBox;
                  final double? piecesPerPack = isPharmacySection ? double.tryParse(piecesPerPackController.text) : product.piecesPerPack;
                  final double? packPrice = isPharmacySection ? double.tryParse(packPriceController.text) : product.packPrice;
                  final double? boxPrice = isPharmacySection ? double.tryParse(boxPriceController.text) : product.boxPrice;

                  final fullUpdatedProduct = Product(
                    id: product.id,
                    branchCode: product.branchCode,
                    name: nameController.text,
                    retailPrice: double.tryParse(retailPriceController.text) ?? product.retailPrice,
                    wholesalePrice: (isPharmacySection && packPrice != null) ? packPrice : (double.tryParse(wholesalePriceController.text) ?? product.wholesalePrice),
                    costPrice: double.tryParse(costPriceController.text) ?? product.costPrice,
                    category: selectedCategory == 'Other' ? otherCategoryController.text : selectedCategory,
                    imageUrl: finalImageUrl,
                    stockQuantity: (requiresImei && imeis != null && imeis.isNotEmpty)
                        ? imeis.length.toDouble()
                        : (double.tryParse(stockController.text) ?? product.stockQuantity),
                    unit: isPharmacySection ? selectedPharmacyUnit : product.unit,
                    isUnlimited: isUnlimited || isService,
                    batchNumber: batchNumberController.text.trim().isNotEmpty ? batchNumberController.text.trim() : null,
                    batchExpiryDate: selectedExpiryDate,
                    requiresPrescription: requiresPrescription,
                    requiresImei: requiresImei,
                    numberOfBoxes: boxesCount,
                    packsPerBox: packsPerBox,
                    boxPrice: boxPrice,
                    piecesPerPack: piecesPerPack,
                    packPrice: packPrice,
                    imeiList: imeis,
                    isService: isService,
                  );
                  await ref.read(productsFutureProvider.notifier).updateProduct(fullUpdatedProduct);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes'),
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildFormTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    String? suffix,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isName = false,
    Function(String)? onChanged,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: [
        if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
        if (keyboardType == const TextInputType.numberWithOptions(decimal: true))
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: validator,
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products, WidgetRef ref, {required bool isAdmin}) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
      final aspectRatio = isMobile ? (constraints.maxWidth < 400 ? 1.2 : 1.4) : 0.72;
      
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: aspectRatio,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          final isLowStock = product.stockQuantity <= product.lowStockThreshold;
          final hasPromo = product.isPromoScheduled;
          final pendingWeight = ref.watch(productPendingWeightProvider(product.name));
          final hasIncoming = pendingWeight > 0;

          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: isMobile 
              ? InkWell(
                  onTap: isAdmin ? () => _showUpdateStockDialog(context, ref, product) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            child: _buildProductImageWidget(product.imageUrl),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormattedName(product.name, const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  if (isAdmin) _buildItemMenu(context, ref, product),
                                ],
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      product.category.toUpperCase(), 
                                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasIncoming) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text('IN TRANSIT', style: TextStyle(color: Colors.blue.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text('₵${product.retailPrice.toStringAsFixed(2)}', 
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        if (hasPromo) 
                                          Text('PROMO ACTIVE', 
                                            style: TextStyle(color: Colors.orange.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green)).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          product.isUnlimited 
                                            ? 'UNLIMITED' 
                                            : '${product.stockQuantity.toStringAsFixed(product.unit == 'unit' ? 0 : 1)}${product.unit == 'unit' ? (product.category == 'CHICKEN' ? " birds" : " pcs") : product.unit}', 
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green))
                                        ),
                                      ),
                                      if (hasIncoming)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} coming', 
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                        )
                                      else if (product.dailyStockAdded > 0 && 
                                          product.lastStockUpdate != null && 
                                          product.lastStockUpdate!.year == DateTime.now().year &&
                                          product.lastStockUpdate!.month == DateTime.now().month &&
                                          product.lastStockUpdate!.day == DateTime.now().day)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('+${product.dailyStockAdded}${product.unit} today', 
                                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _buildProductImageWidget(product.imageUrl, width: double.infinity, height: double.infinity),
                          ),
                          if (isLowStock)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: const Text('LOW STOCK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (hasIncoming)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(4)),
                                child: const Text('IN TRANSIT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (product.retailPrice <= 0)
                            Positioned(
                              top: hasIncoming ? 32 : 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                                child: const Text('PRICING REQ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (hasPromo)
                            Positioned(
                              top: (product.retailPrice <= 0 && hasIncoming) ? 56 : (product.retailPrice <= 0 || hasIncoming ? 32 : 8),
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  product.promoCustomerTarget == PromoCustomerTarget.regularsOnly 
                                    ? '-${product.discountPercentage % 1 == 0 ? product.discountPercentage.toInt() : product.discountPercentage}% REGULARS' 
                                    : '-${product.discountPercentage % 1 == 0 ? product.discountPercentage.toInt() : product.discountPercentage}% PROMO', 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasIncoming) ...[
                                const SizedBox(width: 8),
                                Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} IN TRANSIT', 
                                  style: TextStyle(color: Colors.blue.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildFormattedName(product.name, const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              if (isAdmin) _buildItemMenu(context, ref, product),
                            ],
                          ),
                          Text(product.category, 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('Ret: ₵${product.retailPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, decoration: product.isPromoActiveFor(false, null, ignoreCustomerFilter: true) ? TextDecoration.lineThrough : null)),
                                    ),
                                    if (product.isPromoActiveFor(false, null, ignoreCustomerFilter: true)) 
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('₵${product.getPrice(false, ignoreCustomerFilter: true).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('Whl: ₵${product.wholesalePrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, decoration: product.isPromoActiveFor(true, null, ignoreCustomerFilter: true) ? TextDecoration.lineThrough : null)),
                                    ),
                                    if (product.isPromoActiveFor(true, null, ignoreCustomerFilter: true)) 
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('₵${product.getPrice(true, ignoreCustomerFilter: true).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    product.isUnlimited 
                                      ? 'UNLIMITED' 
                                      : '${product.stockQuantity.toStringAsFixed(product.unit == 'unit' ? 0 : 1)}${product.unit == 'unit' ? " pcs" : product.unit}', 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green))
                                  ),
                                  if (hasIncoming)
                                    Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} coming', 
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                                  else if (product.dailyStockAdded > 0 &&
                                      product.lastStockUpdate != null && 
                                      product.lastStockUpdate!.year == DateTime.now().year &&
                                      product.lastStockUpdate!.month == DateTime.now().month &&
                                      product.lastStockUpdate!.day == DateTime.now().day)
                                    Text('+${product.dailyStockAdded}${product.unit} today', 
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isAdmin)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _showUpdateStockDialog(context, ref, product),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Update Stock', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
          );
        },
      );
    });
  }

  Widget _buildFormattedName(String name, TextStyle baseStyle) {
    if (!name.contains('(')) {
      return Text(name, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final int splitIndex = name.lastIndexOf('(');
    final String mainName = name.substring(0, splitIndex).trim();
    final String range = name.substring(splitIndex).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mainName, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(range, 
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! - 2, 
            color: baseStyle.color?.withValues(alpha: 0.7) ?? Colors.black54,
            fontWeight: FontWeight.normal,
          ), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }

  Widget _buildItemMenu(BuildContext context, WidgetRef ref, Product product) {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'edit') {
          _showEditProductDialog(context, ref, product);
        } else if (val == 'delete') {
          _confirmDeleteProduct(context, ref, product);
        } else if (val == 'stop_promo') {
          ref.read(productsFutureProvider.notifier).removePromotion(product.id);
        } else if (val == 'extend_promo') {
          _showPromotionDialog(context, ref, [product], initialProduct: product);
        }
      },
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit Details'),
            ],
          ),
        ),
        if (product.discountPercentage > 0) ...[
          const PopupMenuItem(
            value: 'extend_promo',
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('Extend/Modify Promo'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'stop_promo',
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('Stop Promotion'),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Product', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showUpdateStockDialog(BuildContext context, WidgetRef ref, Product product) {
    final formKey = GlobalKey<FormState>();
    final stockController = TextEditingController();
    final theme = Theme.of(context);
    WeightUnit selectedUnit = WeightUnit.values.firstWhere((u) => u.name == product.unit, orElse: () => WeightUnit.kg);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.primaryMaroon),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Update Stock: ${product.name}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Inventory', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(WeightConverter.formatShort(product.stockQuantity, unit: product.unit), 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.primary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          decoration: InputDecoration(
                            labelText: selectedUnit == WeightUnit.unit ? 'Add/Remove Qty' : 'Add/Remove (${selectedUnit.name})',
                            hintText: 'e.g. 50.0 or -10.5',
                            helperText: 'Use negative to reduce',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                          autofocus: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const Text('UNIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                          ToggleButtons(
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                            isSelected: [
                              selectedUnit == WeightUnit.kg, 
                              selectedUnit == WeightUnit.g,
                              selectedUnit == WeightUnit.lb,
                              selectedUnit == WeightUnit.unit,
                            ],
                            onPressed: (index) {
                              setState(() {
                                selectedUnit = WeightUnit.values[index];
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            selectedColor: Colors.white,
                            fillColor: theme.colorScheme.primary,
                            children: const [
                              Text('kg', style: TextStyle(fontSize: 9)),
                              Text('g', style: TextStyle(fontSize: 9)),
                              Text('lb', style: TextStyle(fontSize: 9)),
                              Text('pcs', style: TextStyle(fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  double change = double.tryParse(stockController.text) ?? 0.0;
                  if (change != 0) {
                    // Normalize to master unit (kg or unit)
                    if (product.unit == 'unit') {
                      // If master is unit, we just add the absolute value
                      ref.read(productsFutureProvider.notifier).updateStock(product.id, change);
                    } else {
                      // If master is weight (kg), we convert from selected unit to kg
                      if (selectedUnit == WeightUnit.g) change = WeightConverter.fromG(change);
                      if (selectedUnit == WeightUnit.lb) change = WeightConverter.toKg(change);
                      ref.read(productsFutureProvider.notifier).updateStock(product.id, change);
                    }
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${product.name}? This will remove it from the catalog for all terminals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(productsFutureProvider.notifier).deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} deleted successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Product'),
          ),
        ],
      ),
    );
  }



  String _normalizeCategory(Product p) {
    if (p.category.trim().isEmpty) return 'Other';
    return p.category.trim();
  }

  Widget _buildProductImageWidget(String imageUrl, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image)),
      );
    }
    if (imageUrl.startsWith('data:image') || imageUrl.contains(';base64,')) {
      final bytes = getDecodedCardImage(imageUrl);
      if (bytes == null) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.image)),
        );
      }
      return Image.memory(
        bytes,
        gaplessPlayback: true,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: _buildImageError,
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        gaplessPlayback: true,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: _buildImageError,
      );
    }
    return Image.network(
      imageUrl,
      gaplessPlayback: true,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: _buildImageError,
    );
  }

  Widget _buildImageError(BuildContext c, Object e, StackTrace? s) {
    return const Center(child: Icon(Icons.image));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/image_picker_helper.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/product_card.dart';
import '../../services/product_service.dart';
import '../../services/branch_provider.dart';
import '../../models/product.dart';
import '../../core/uuid_utils.dart';
import 'package:intl/intl.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/passcode_guard.dart';
import '../../services/product_seeder.dart';
import '../../models/tech_shop_models.dart';
import '../../services/tech_shop_service.dart';
import '../../widgets/role_pop_scope.dart';

class InventoryControlScreen extends ConsumerStatefulWidget {
  const InventoryControlScreen({super.key});

  @override
  ConsumerState<InventoryControlScreen> createState() => _InventoryControlScreenState();
}

class _InventoryControlScreenState extends ConsumerState<InventoryControlScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSector = 'all'; // 'all', 'pharmacy', 'phones', 'barber'

  String _getSector(Product p) {
    final cat = p.category.toUpperCase();
    final name = p.name.toUpperCase();

    // 1. Tech / Phones Sector check
    if (p.requiresImei ||
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
        name.contains('IPHONE') ||
        name.contains('SAMSUNG') ||
        name.contains('AIRPODS') ||
        name.contains('GIG')) {
      return 'phones';
    }

    // 2. Barbershop / Grooming Sector check
    if (p.isService ||
        cat.contains('BARBER') ||
        cat.contains('HAIR') ||
        cat.contains('BEARD') ||
        cat.contains('GROOM') ||
        cat.contains('SALON') ||
        cat.contains('STYL') ||
        cat.contains('CARE PRODUCTS')) {
      return 'barber';
    }

    // 3. All non-tech, non-barber products (drugs, pharmaceuticals, custom medicine categories) belong to pharmacy!
    return 'pharmacy';
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
    final barberCount = activeProducts.where((p) => _getSector(p) == 'barber').length;
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
            _sectorPill('all', 'All Inventory', Icons.inventory_2_outlined, Colors.blue.shade800, totalCount),
            const SizedBox(width: 6),
            _sectorPill('pharmacy', 'Pharmacy', Icons.medical_services_outlined, const Color(0xFF2E7D32), pharmacyCount),
            const SizedBox(width: 6),
            _sectorPill('phones', 'Phones & Tech', Icons.phone_android_outlined, const Color(0xFFE65100), phonesCount),
            const SizedBox(width: 6),
            _sectorPill('barber', 'Barbershop & Services', Icons.content_cut_outlined, const Color(0xFF1565C0), barberCount),
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

    final actionButtons = [
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

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    final products = ref.read(productsFutureProvider).value ?? [];
    final branchesAsync = ref.read(branchesProvider);
    final branches = branchesAsync.value ?? [];
    final formKey = GlobalKey<FormState>();
    
    String selectedBranchCode = (user?.branchCode != null && user!.branchCode!.trim().isNotEmpty)
        ? user.branchCode!.trim()
        : 'GLOBAL';
    final nameController = TextEditingController();
    final defaultUnit = _selectedSector == 'pharmacy' ? 'tablets' : 'pcs';
    final unitController = TextEditingController(text: defaultUnit);
    final retailPriceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController();
    final alertQuantityController = TextEditingController(text: '5');
    final otherCategoryController = TextEditingController();
    final theme = Theme.of(context);

    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;
    DateTime? selectedExpiryDate;

    List<String> sectorPresetCategories = [];
    if (_selectedSector == 'pharmacy') {
      sectorPresetCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
      ];
    } else if (_selectedSector == 'phones') {
      sectorPresetCategories = [
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
      ];
    } else if (_selectedSector == 'barber') {
      sectorPresetCategories = [
        'Barber Services', 'Grooming & Treatments', 'Care Products',
      ];
    } else {
      sectorPresetCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
        'Barber Services', 'Grooming & Treatments', 'Care Products',
      ];
    }

    final existingSectorCats = products
        .where((p) => !p.isDeleted && (_selectedSector == 'all' || _getSector(p) == _selectedSector))
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet();

    final List<String> categories = [
      ...{...sectorPresetCategories, ...existingSectorCats},
      'Other'
    ];

    String selectedCategory = categories.first;
    final imeiInputController = TextEditingController();
    final List<String> pendingImeis = [];
    bool trackImei = _selectedSector == 'phones' || selectedCategory.toLowerCase().contains('phone') || selectedCategory.toLowerCase().contains('smart');

    final List<String> unitOptions = [
      'pcs', 'tablets', 'capsules', 'bottles', 'packs', 'boxes', 'mils', 'service', 'unit'
    ];

    final Color sectorColor = _selectedSector == 'pharmacy'
        ? const Color(0xFF2E7D32)
        : (_selectedSector == 'phones'
            ? const Color(0xFFE65100)
            : (_selectedSector == 'barber'
                ? const Color(0xFF673AB7)
                : theme.colorScheme.primary));

    final IconData sectorIcon = _selectedSector == 'pharmacy'
        ? Icons.medication_outlined
        : (_selectedSector == 'phones'
            ? Icons.smartphone_outlined
            : (_selectedSector == 'barber'
                ? Icons.content_cut_outlined
                : Icons.inventory_2_outlined));

    final String sectorTitle = _selectedSector == 'pharmacy'
        ? 'Add Pharmacy Product'
        : (_selectedSector == 'phones'
            ? 'Add Tech / Phone Product'
            : (_selectedSector == 'barber'
                ? 'Add Barber Item / Service'
                : 'Add New Product'));

    final String sectorSubtitle = _selectedSector == 'pharmacy'
        ? 'Enter pharmaceutical medication details & stock'
        : (_selectedSector == 'phones'
            ? 'Add phones, gadgets, or accessories to inventory'
            : (_selectedSector == 'barber'
                ? 'Add barber product or grooming service'
                : 'Enter product specifications and inventory pricing'));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isService = unitController.text.toLowerCase() == 'service' ||
              selectedCategory == 'Barber Services' ||
              selectedCategory == 'Grooming & Treatments' ||
              selectedCategory == 'Repairs & Services';

          return Dialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modern Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          sectorColor.withValues(alpha: 0.12),
                          sectorColor.withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sectorColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(sectorIcon, color: sectorColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sectorTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sectorSubtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isUploading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image Picker Card
                            Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final XFile? image = await ImagePickerHelper.pickAndCompressImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    setState(() {
                                      imageBytes = bytes;
                                      imageName = image.name;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: imageBytes != null ? sectorColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: imageBytes != null ? 2 : 1.2,
                                    ),
                                  ),
                                  child: imageBytes != null
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(14),
                                              child: Image.memory(imageBytes!, fit: BoxFit.cover),
                                            ),
                                            Positioned(
                                              bottom: 4,
                                              right: 4,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: sectorColor.withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(Icons.add_a_photo_outlined, color: sectorColor, size: 20),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Add Image',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Basic Info Section
                            _buildFormSectionHeader(context, 'Basic Details', Icons.info_outline_rounded, sectorColor),
                            _buildFormTextField(
                              context: context,
                              controller: nameController,
                              label: 'Product Name',
                              hint: 'e.g. Paracetamol Extra 500mg',
                              icon: Icons.medication_outlined,
                              isName: true,
                              activeColor: sectorColor,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Category',
                                    value: selectedCategory,
                                    icon: Icons.category_outlined,
                                    activeColor: sectorColor,
                                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() {
                                      selectedCategory = v!;
                                      if (selectedCategory == 'Barber Services' || selectedCategory == 'Grooming & Treatments' || selectedCategory == 'Repairs & Services') {
                                        unitController.text = 'service';
                                      }
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Target Branch',
                                    value: branches.any((b) => b.code == selectedBranchCode) ? selectedBranchCode : 'GLOBAL',
                                    icon: Icons.storefront_outlined,
                                    activeColor: sectorColor,
                                    items: [
                                      const DropdownMenuItem(value: 'GLOBAL', child: Text('All Branches (Global)', overflow: TextOverflow.ellipsis)),
                                      ...branches.map((b) => DropdownMenuItem(
                                        value: b.code,
                                        child: Text('${b.name} (${b.code})', overflow: TextOverflow.ellipsis),
                                      )),
                                    ],
                                    onChanged: (v) => setState(() => selectedBranchCode = v!),
                                  ),
                                ),
                              ],
                            ),
                            if (selectedCategory == 'Other') ...[
                              const SizedBox(height: 12),
                              _buildFormTextField(
                                context: context,
                                controller: otherCategoryController,
                                label: 'Custom Category Name',
                                hint: 'e.g. Special Medicine',
                                icon: Icons.edit_note,
                                activeColor: sectorColor,
                                validator: (v) => (selectedCategory == 'Other' && (v == null || v.trim().isEmpty)) ? 'Category required' : null,
                              ),
                            ],

                            // Pricing & Unit Section
                            _buildFormSectionHeader(context, 'Pricing & Units', Icons.payments_outlined, sectorColor),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Unit',
                                    value: unitOptions.contains(unitController.text) ? unitController.text : 'pcs',
                                    icon: Icons.straighten_outlined,
                                    activeColor: sectorColor,
                                    items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase()))).toList(),
                                    onChanged: (v) => setState(() => unitController.text = v!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFormTextField(
                                    context: context,
                                    controller: retailPriceController,
                                    label: 'Selling Price',
                                    prefix: 'GH₵ ',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    activeColor: sectorColor,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFormTextField(
                                    context: context,
                                    controller: costPriceController,
                                    label: isService ? 'Fixed Commission' : 'Cost Price',
                                    hint: isService ? 'Fixed cash commission' : null,
                                    prefix: 'GH₵ ',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    activeColor: sectorColor,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (isService) ...[
                              const SizedBox(height: 6),
                              Text(
                                'ℹ️ Straight fixed cash commission earned by barber/staff per service (defined here in Stock Control).',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: sectorColor),
                              ),
                            ],

                            // Inventory Section (if not service)
                            if (!isService) ...[
                              _buildFormSectionHeader(context, 'Stock & Alerts', Icons.inventory_2_outlined, sectorColor),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormTextField(
                                      context: context,
                                      controller: stockController,
                                      label: 'Initial Quantity',
                                      icon: Icons.inventory_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      activeColor: sectorColor,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormTextField(
                                      context: context,
                                      controller: alertQuantityController,
                                      label: 'Low Stock Alert',
                                      icon: Icons.warning_amber_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      activeColor: sectorColor,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Expiry Date (Pharmacy sector only)
                            if (_selectedSector == 'pharmacy') ...[
                              _buildFormSectionHeader(context, 'Batch Expiry', Icons.event_outlined, sectorColor),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                    helpText: 'SELECT DRUG EXPIRY DATE',
                                  );
                                  if (picked != null) {
                                    setState(() => selectedExpiryDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selectedExpiryDate != null
                                        ? (selectedExpiryDate!.isBefore(DateTime.now().add(const Duration(days: 180)))
                                            ? Colors.orange.withValues(alpha: 0.08)
                                            : sectorColor.withValues(alpha: 0.06))
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedExpiryDate != null
                                          ? (selectedExpiryDate!.isBefore(DateTime.now().add(const Duration(days: 180)))
                                              ? Colors.orange.withValues(alpha: 0.7)
                                              : sectorColor.withValues(alpha: 0.6))
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: selectedExpiryDate != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.event_available_outlined,
                                          size: 20,
                                          color: selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'DRUG EXPIRY DATE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              selectedExpiryDate != null
                                                  ? DateFormat('dd MMMM yyyy').format(selectedExpiryDate!)
                                                  : 'Tap to select drug expiry date (Optional)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selectedExpiryDate != null ? FontWeight.w600 : FontWeight.normal,
                                                color: selectedExpiryDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selectedExpiryDate != null)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          tooltip: 'Clear expiry date',
                                          onPressed: () => setState(() => selectedExpiryDate = null),
                                        )
                                      else
                                        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // IMEI / Serial Tracking Section
                            if (!isService) ...[
                              const SizedBox(height: 12),
                              _buildFormSectionHeader(context, 'Device Tracking (IMEI / Serial)', Icons.qr_code_scanner_outlined, sectorColor),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Track IMEI / Serial Numbers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: const Text('Require unique IMEI registration on POS sale & stock tracking', style: TextStyle(fontSize: 11)),
                                value: trackImei,
                                activeTrackColor: sectorColor,
                                onChanged: (val) => setState(() => trackImei = val),
                              ),
                              if (trackImei) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: imeiInputController,
                                        decoration: InputDecoration(
                                          labelText: 'Enter or Paste IMEI / Serial',
                                          hintText: 'e.g. 354892019283741 (comma/space/newline separated)',
                                          isDense: true,
                                          prefixIcon: const Icon(Icons.qr_code, size: 20),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onSubmitted: (val) {
                                          if (val.trim().isNotEmpty) {
                                            final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                                            setState(() {
                                              for (final imei in split) {
                                                if (!pendingImeis.contains(imei)) pendingImeis.add(imei);
                                              }
                                              imeiInputController.clear();
                                              if (stockController.text.isEmpty || stockController.text == '0') {
                                                stockController.text = pendingImeis.length.toString();
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        final val = imeiInputController.text;
                                        if (val.trim().isNotEmpty) {
                                          final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                                          setState(() {
                                            for (final imei in split) {
                                              if (!pendingImeis.contains(imei)) pendingImeis.add(imei);
                                            }
                                            imeiInputController.clear();
                                            if (stockController.text.isEmpty || stockController.text == '0') {
                                              stockController.text = pendingImeis.length.toString();
                                            }
                                          });
                                        }
                                      },
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                                if (pendingImeis.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: pendingImeis.map((imei) => Chip(
                                      label: Text(imei, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                      deleteIcon: const Icon(Icons.close, size: 14),
                                      onDeleted: () => setState(() => pendingImeis.remove(imei)),
                                      backgroundColor: sectorColor.withValues(alpha: 0.1),
                                    )).toList(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${pendingImeis.length} IMEI(s) staged for initial stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sectorColor)),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isUploading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: isUploading ? null : () async {
                              if (formKey.currentState!.validate()) {
                                setState(() => isUploading = true);
                                
                                String finalImageUrl = '';
                                if (imageBytes != null && imageName != null) {
                                  final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                                    imageBytes!, 
                                    'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                                  );
                                  if (uploadedUrl != null) finalImageUrl = uploadedUrl;
                                }

                                final price = double.tryParse(retailPriceController.text) ?? 0.0;
                                final cost = double.tryParse(costPriceController.text) ?? 0.0;
                                final qty = double.tryParse(stockController.text) ?? 0.0;
                                final alertQty = double.tryParse(alertQuantityController.text) ?? 5.0;

                                final customCat = otherCategoryController.text.trim();
                                final finalCategory = selectedCategory == 'Other'
                                    ? (customCat.isEmpty ? 'General Medication' : customCat)
                                    : selectedCategory;

                                final newProduct = Product(
                                  id: UuidUtils.generate(),
                                  branchCode: selectedBranchCode == 'GLOBAL' ? null : selectedBranchCode,
                                  category: finalCategory,
                                  name: nameController.text.trim(),
                                  unit: unitController.text.trim(),
                                  retailPrice: price,
                                  wholesalePrice: price,
                                  costPrice: cost,
                                  commissionAmount: isService ? cost : null,
                                  stockQuantity: isService ? 9999.0 : qty,
                                  lowStockThreshold: alertQty,
                                  imageUrl: finalImageUrl,
                                  batchExpiryDate: selectedExpiryDate,
                                  requiresPrescription: _selectedSector == 'pharmacy' || selectedExpiryDate != null,
                                  isService: isService,
                                  isUnlimited: isService,
                                  imeiList: pendingImeis.isNotEmpty ? pendingImeis : null,
                                  requiresImei: trackImei || pendingImeis.isNotEmpty,
                                );

                                await ref.read(productsFutureProvider.notifier).addProduct(newProduct);
                                for (final imei in pendingImeis) {
                                  ref.read(imeiInventoryProvider.notifier).registerIMEI(
                                    IMEIRecord(imei: imei, deviceModel: newProduct.name, status: 'In Stock'),
                                  );
                                }
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: sectorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 1,
                            ),
                            child: isUploading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 18),
                                    SizedBox(width: 8),
                                    Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final formKey = GlobalKey<FormState>();
    final branchesAsync = ref.read(branchesProvider);
    final branches = branchesAsync.value ?? [];
    String selectedBranchCode = (product.branchCode != null && product.branchCode!.trim().isNotEmpty)
        ? product.branchCode!.trim()
        : 'GLOBAL';
    final nameController = TextEditingController(text: product.name);
    final unitController = TextEditingController(text: product.unit.isNotEmpty ? product.unit : 'pcs');
    final retailPriceController = TextEditingController(text: product.retailPrice.toString());
    final initialCostOrComm = (product.isService && product.serviceCommission > 0)
        ? product.serviceCommission
        : product.costPrice;
    final costPriceController = TextEditingController(text: initialCostOrComm.toString());
    final stockController = TextEditingController(text: product.stockQuantity.toString());
    final alertQuantityController = TextEditingController(text: product.lowStockThreshold.toString());
    final otherCategoryController = TextEditingController();

    final theme = Theme.of(context);

    final sector = _getSector(product);
    List<String> sectorPresetCategories = [];
    if (sector == 'pharmacy') {
      sectorPresetCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
      ];
    } else if (sector == 'phones') {
      sectorPresetCategories = [
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
      ];
    } else if (sector == 'barber') {
      sectorPresetCategories = [
        'Barber Services', 'Grooming & Treatments', 'Care Products',
      ];
    } else {
      sectorPresetCategories = [
        'Antimalarial', 'Antibiotic', 'Analgesic', 'NSAID', 'Cough & Cold',
        'Cardiovascular', 'Gastrointestinal', 'Contraceptive', 'Supplement',
        'Topical & Gel', 'Sedative', 'General Medication',
        'Smartphones', 'Chargers & Power', 'Cases & Protection', 'Screen Protectors',
        'Audio & Sound', 'Smart Wearables', 'Mounts & Holders', 'Repairs & Services',
        'Barber Services', 'Grooming & Treatments', 'Care Products',
      ];
    }

    final products = ref.read(productsFutureProvider).value ?? [];
    final existingSectorCats = products
        .where((p) => !p.isDeleted && _getSector(p) == sector)
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet();

    final List<String> categories = [
      ...{...sectorPresetCategories, ...existingSectorCats},
      'Other'
    ];

    final List<String> unitOptions = [
      'pcs', 'tablets', 'capsules', 'bottles', 'packs', 'boxes', 'mils', 'service', 'unit'
    ];

    String selectedCategory = categories.contains(product.category) ? product.category : 'Other';
    if (selectedCategory == 'Other') {
      otherCategoryController.text = product.category;
    }

    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;
    DateTime? selectedExpiryDate = product.batchExpiryDate;
    final imeiInputController = TextEditingController();
    final List<String> currentImeis = List<String>.from(product.imeiList ?? []);
    bool trackImei = product.requiresImei || currentImeis.isNotEmpty || sector == 'phones';

    final Color sectorColor = sector == 'pharmacy'
        ? const Color(0xFF2E7D32)
        : (sector == 'phones'
            ? const Color(0xFFE65100)
            : (sector == 'barber'
                ? const Color(0xFF673AB7)
                : theme.colorScheme.primary));

    final IconData sectorIcon = sector == 'pharmacy'
        ? Icons.medication_outlined
        : (sector == 'phones'
            ? Icons.smartphone_outlined
            : (sector == 'barber'
                ? Icons.content_cut_outlined
                : Icons.inventory_2_outlined));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isService = unitController.text.toLowerCase() == 'service' ||
              selectedCategory == 'Barber Services' ||
              selectedCategory == 'Grooming & Treatments' ||
              selectedCategory == 'Repairs & Services' ||
              product.isService;

          return Dialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modern Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          sectorColor.withValues(alpha: 0.12),
                          sectorColor.withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border(
                        bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sectorColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(sectorIcon, color: sectorColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Product',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isUploading ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Image Picker Card
                            Center(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final XFile? image = await ImagePickerHelper.pickAndCompressImage(source: ImageSource.gallery);
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    setState(() {
                                      imageBytes = bytes;
                                      imageName = image.name;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: (imageBytes != null || product.imageUrl.isNotEmpty) ? sectorColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: imageBytes != null
                                            ? Image.memory(imageBytes!, fit: BoxFit.cover)
                                            : _buildProductImageWidget(product.imageUrl),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Basic Info Section
                            _buildFormSectionHeader(context, 'Basic Details', Icons.info_outline_rounded, sectorColor),
                            _buildFormTextField(
                              context: context,
                              controller: nameController,
                              label: 'Product Name',
                              icon: Icons.medication_outlined,
                              isName: true,
                              activeColor: sectorColor,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Category',
                                    value: selectedCategory,
                                    icon: Icons.category_outlined,
                                    activeColor: sectorColor,
                                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() {
                                      selectedCategory = v!;
                                      if (selectedCategory == 'Barber Services' || selectedCategory == 'Grooming & Treatments' || selectedCategory == 'Repairs & Services') {
                                        unitController.text = 'service';
                                      }
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Target Branch',
                                    value: branches.any((b) => b.code == selectedBranchCode) ? selectedBranchCode : 'GLOBAL',
                                    icon: Icons.storefront_outlined,
                                    activeColor: sectorColor,
                                    items: [
                                      const DropdownMenuItem(value: 'GLOBAL', child: Text('All Branches (Global)', overflow: TextOverflow.ellipsis)),
                                      ...branches.map((b) => DropdownMenuItem(
                                        value: b.code,
                                        child: Text('${b.name} (${b.code})', overflow: TextOverflow.ellipsis),
                                      )),
                                    ],
                                    onChanged: (v) => setState(() => selectedBranchCode = v!),
                                  ),
                                ),
                              ],
                            ),
                            if (selectedCategory == 'Other') ...[
                              const SizedBox(height: 12),
                              _buildFormTextField(
                                context: context,
                                controller: otherCategoryController,
                                label: 'Custom Category Name',
                                isName: true,
                                activeColor: sectorColor,
                                validator: (v) => (selectedCategory == 'Other' && (v == null || v.trim().isEmpty)) ? 'Category required' : null,
                              ),
                            ],

                            // Pricing & Unit Section
                            _buildFormSectionHeader(context, 'Pricing & Units', Icons.payments_outlined, sectorColor),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormDropdown<String>(
                                    context: context,
                                    label: 'Unit',
                                    value: unitOptions.contains(unitController.text) ? unitController.text : 'pcs',
                                    icon: Icons.straighten_outlined,
                                    activeColor: sectorColor,
                                    items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u.toUpperCase()))).toList(),
                                    onChanged: (v) => setState(() => unitController.text = v!),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFormTextField(
                                    context: context,
                                    controller: retailPriceController,
                                    label: 'Selling Price',
                                    prefix: 'GH₵ ',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    activeColor: sectorColor,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFormTextField(
                                    context: context,
                                    controller: costPriceController,
                                    label: isService ? 'Fixed Commission' : 'Cost Price',
                                    hint: isService ? 'Fixed cash commission' : null,
                                    prefix: 'GH₵ ',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    activeColor: sectorColor,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (isService) ...[
                              const SizedBox(height: 6),
                              Text(
                                'ℹ️ Straight fixed cash commission earned by barber/staff per service (defined here in Stock Control).',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: sectorColor),
                              ),
                            ],

                            // Inventory Section (if not service)
                            if (!isService) ...[
                              _buildFormSectionHeader(context, 'Stock & Alerts', Icons.inventory_2_outlined, sectorColor),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormTextField(
                                      context: context,
                                      controller: stockController,
                                      label: 'Quantity / Stock',
                                      icon: Icons.inventory_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      activeColor: sectorColor,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid';
                                        if (double.parse(v) < 0) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFormTextField(
                                      context: context,
                                      controller: alertQuantityController,
                                      label: 'Low Stock Alert',
                                      icon: Icons.warning_amber_outlined,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      activeColor: sectorColor,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        if (double.tryParse(v) == null) return 'Invalid';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Expiry Date (Pharmacy sector only)
                            if (sector == 'pharmacy') ...[
                              _buildFormSectionHeader(context, 'Batch Expiry', Icons.event_outlined, sectorColor),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                                    helpText: 'SELECT DRUG EXPIRY DATE',
                                  );
                                  if (picked != null) {
                                    setState(() => selectedExpiryDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selectedExpiryDate != null
                                        ? (selectedExpiryDate!.isBefore(DateTime.now().add(const Duration(days: 180)))
                                            ? Colors.orange.withValues(alpha: 0.08)
                                            : sectorColor.withValues(alpha: 0.06))
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedExpiryDate != null
                                          ? (selectedExpiryDate!.isBefore(DateTime.now().add(const Duration(days: 180)))
                                              ? Colors.orange.withValues(alpha: 0.7)
                                              : sectorColor.withValues(alpha: 0.6))
                                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: selectedExpiryDate != null ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.event_available_outlined,
                                          size: 20,
                                          color: selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'EXPIRY DATE',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                color: selectedExpiryDate != null ? sectorColor : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              selectedExpiryDate != null
                                                  ? DateFormat('dd MMMM yyyy').format(selectedExpiryDate!)
                                                  : 'Tap to select drug expiry date (Optional)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selectedExpiryDate != null ? FontWeight.w600 : FontWeight.normal,
                                                color: selectedExpiryDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selectedExpiryDate != null)
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          tooltip: 'Clear expiry date',
                                          onPressed: () => setState(() => selectedExpiryDate = null),
                                        )
                                      else
                                        Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // IMEI / Serial Tracking Section
                            if (!isService) ...[
                              const SizedBox(height: 12),
                              _buildFormSectionHeader(context, 'Device Tracking (IMEI / Serial)', Icons.qr_code_scanner_outlined, sectorColor),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Track IMEI / Serial Numbers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: const Text('Require unique IMEI registration on POS sale & stock tracking', style: TextStyle(fontSize: 11)),
                                value: trackImei,
                                activeTrackColor: sectorColor,
                                onChanged: (val) => setState(() => trackImei = val),
                              ),
                              if (trackImei) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: imeiInputController,
                                        decoration: InputDecoration(
                                          labelText: 'Add IMEI / Serial',
                                          hintText: 'e.g. 354892019283741 (comma/space/newline separated)',
                                          isDense: true,
                                          prefixIcon: const Icon(Icons.qr_code, size: 20),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onSubmitted: (val) {
                                          if (val.trim().isNotEmpty) {
                                            final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                                            setState(() {
                                              for (final imei in split) {
                                                if (!currentImeis.contains(imei)) currentImeis.add(imei);
                                              }
                                              imeiInputController.clear();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        final val = imeiInputController.text;
                                        if (val.trim().isNotEmpty) {
                                          final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                                          setState(() {
                                            for (final imei in split) {
                                              if (!currentImeis.contains(imei)) currentImeis.add(imei);
                                            }
                                            imeiInputController.clear();
                                          });
                                        }
                                      },
                                      child: const Text('Add'),
                                    ),
                                  ],
                                ),
                                if (currentImeis.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: currentImeis.map((imei) => Chip(
                                      label: Text(imei, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                      deleteIcon: const Icon(Icons.close, size: 14),
                                      onDeleted: () => setState(() => currentImeis.remove(imei)),
                                      backgroundColor: sectorColor.withValues(alpha: 0.1),
                                    )).toList(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${currentImeis.length} IMEI(s) registered for this product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sectorColor)),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isUploading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: isUploading ? null : () async {
                              if (formKey.currentState!.validate()) {
                                setState(() => isUploading = true);

                                String finalImageUrl = product.imageUrl;
                                if (imageBytes != null && imageName != null) {
                                  final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                                    imageBytes!, 
                                    'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                                  );
                                  if (uploadedUrl != null) finalImageUrl = uploadedUrl;
                                }

                                final price = double.tryParse(retailPriceController.text) ?? product.retailPrice;
                                final cost = double.tryParse(costPriceController.text) ?? product.costPrice;
                                final qty = double.tryParse(stockController.text) ?? product.stockQuantity;
                                final alertQty = double.tryParse(alertQuantityController.text) ?? product.lowStockThreshold;

                                final updatedProduct = product.copyWith(
                                  branchCode: selectedBranchCode == 'GLOBAL' ? null : selectedBranchCode,
                                  category: selectedCategory == 'Other' ? otherCategoryController.text.trim() : selectedCategory,
                                  name: nameController.text.trim(),
                                  unit: unitController.text.trim(),
                                  retailPrice: price,
                                  wholesalePrice: price,
                                  costPrice: cost,
                                  commissionAmount: isService ? cost : product.commissionAmount,
                                  stockQuantity: isService ? 9999.0 : qty,
                                  lowStockThreshold: alertQty,
                                  imageUrl: finalImageUrl,
                                  batchExpiryDate: selectedExpiryDate,
                                  isService: isService,
                                  isUnlimited: isService || product.isUnlimited,
                                  imeiList: currentImeis,
                                  requiresImei: trackImei || currentImeis.isNotEmpty,
                                );

                                await ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
                                for (final imei in currentImeis) {
                                  if (product.imeiList == null || !product.imeiList!.contains(imei)) {
                                    ref.read(imeiInventoryProvider.notifier).registerIMEI(
                                      IMEIRecord(imei: imei, deviceModel: updatedProduct.name, status: 'In Stock'),
                                    );
                                  }
                                }
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: sectorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 1,
                            ),
                            child: isUploading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 18),
                                    SizedBox(width: 8),
                                    Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.2), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildFormDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final focusColor = activeColor ?? theme.colorScheme.primary;
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 19) : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusColor, width: 1.8),
        ),
        labelStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
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
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final focusColor = activeColor ?? theme.colorScheme.primary;
    return TextFormField(
      controller: controller,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, size: 19) : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusColor, width: 1.8),
        ),
        labelStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: [
        if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-\.\,\/\(\)\+\%]')),
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

          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: isMobile 
              ? InkWell(
                  onTap: (isAdmin && !product.isService) ? () => _showUpdateStockDialog(context, ref, product) : null,
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
                                        if (product.isService)
                                          Text('Fixed Comm: ₵${product.serviceCommission.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF673AB7))),
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
                                      if (product.dailyStockAdded > 0 && 
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
                          if (product.retailPrice <= 0)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                                child: const Text('PRICING REQ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (hasPromo)
                            Positioned(
                              top: product.retailPrice <= 0 ? 32 : 8,
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
                                      child: Text('Price: ₵${product.retailPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, decoration: product.isPromoActiveFor(false, null, ignoreCustomerFilter: true) ? TextDecoration.lineThrough : null)),
                                    ),
                                    if (product.isService)
                                      Text('Fixed Comm: ₵${product.serviceCommission.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF673AB7))),
                                    if (product.isPromoActiveFor(false, null, ignoreCustomerFilter: true)) 
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('₵${product.getPrice(false, ignoreCustomerFilter: true).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
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
                                  if (product.dailyStockAdded > 0 &&
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
                          if (isAdmin && !product.isService)
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
    final imeiInputController = TextEditingController();
    final theme = Theme.of(context);
    final String productUnit = product.unit.isNotEmpty ? product.unit : 'pcs';
    bool trackImei = product.requiresImei || 
        product.category.toLowerCase().contains('phone') || 
        product.category.toLowerCase().contains('smart') || 
        (product.imeiList != null && product.imeiList!.isNotEmpty);
    final List<String> pendingImeis = [];
    final List<String> existingImeis = List<String>.from(product.imeiList ?? []);

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
              constraints: const BoxConstraints(maxWidth: 440),
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
                                child: Text('${product.stockQuantity % 1 == 0 ? product.stockQuantity.toInt() : product.stockQuantity} $productUnit', 
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          decoration: InputDecoration(
                            labelText: 'Add/Remove ($productUnit)',
                            hintText: 'e.g. 50 or -10',
                            helperText: 'Use negative (-) to reduce stock',
                            border: const OutlineInputBorder(),
                            suffixText: productUnit,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                          autofocus: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid quantity';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          productUnit.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Row(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFFE65100)),
                        SizedBox(width: 8),
                        Text('Track IMEI / Serial Numbers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    subtitle: const Text('Record individual phone IMEIs for POS and warranty', style: TextStyle(fontSize: 11)),
                    value: trackImei,
                    activeTrackColor: const Color(0xFFE65100),
                    onChanged: (val) => setState(() => trackImei = val),
                  ),
                  if (trackImei) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imeiInputController,
                            decoration: InputDecoration(
                              labelText: 'Add New IMEI / Serial',
                              hintText: 'e.g. 359123456789012 (comma/space/newline separated)',
                              isDense: true,
                              prefixIcon: const Icon(Icons.qr_code, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                                setState(() {
                                  for (final imei in split) {
                                    if (!pendingImeis.contains(imei) && !existingImeis.contains(imei)) {
                                      pendingImeis.add(imei);
                                    }
                                  }
                                  imeiInputController.clear();
                                  if (pendingImeis.isNotEmpty) {
                                    stockController.text = pendingImeis.length.toString();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            final val = imeiInputController.text;
                            if (val.trim().isNotEmpty) {
                              final split = val.split(RegExp(r'[\s,;\n]+')).where((s) => s.trim().isNotEmpty).map((s) => s.trim());
                              setState(() {
                                for (final imei in split) {
                                  if (!pendingImeis.contains(imei) && !existingImeis.contains(imei)) {
                                    pendingImeis.add(imei);
                                  }
                                }
                                imeiInputController.clear();
                                if (pendingImeis.isNotEmpty) {
                                  stockController.text = pendingImeis.length.toString();
                                }
                              });
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (pendingImeis.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('New IMEIs to Add (${pendingImeis.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: pendingImeis.map((imei) => Chip(
                          label: Text(imei, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => setState(() {
                            pendingImeis.remove(imei);
                            if (stockController.text == (pendingImeis.length + 1).toString()) {
                              stockController.text = pendingImeis.length.toString();
                            }
                          }),
                          backgroundColor: Colors.green.withValues(alpha: 0.15),
                        )).toList(),
                      ),
                    ],
                    if (existingImeis.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Existing Saved IMEIs in Stock (${existingImeis.length}):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: existingImeis.take(10).map((imei) => Chip(
                          label: Text(imei, style: const TextStyle(fontSize: 10)),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        )).toList(),
                      ),
                      if (existingImeis.length > 10)
                        Text('+ ${existingImeis.length - 10} more saved IMEIs', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                    ],
                  ],
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
                  final change = double.tryParse(stockController.text) ?? 0.0;
                  if (change != 0 || pendingImeis.isNotEmpty || trackImei != product.requiresImei) {
                    ref.read(productsFutureProvider.notifier).updateStock(
                      product.id, 
                      change,
                      newImeis: pendingImeis.isNotEmpty ? pendingImeis : null,
                      requiresImei: trackImei,
                    );
                    for (final imei in pendingImeis) {
                      ref.read(imeiInventoryProvider.notifier).registerIMEI(
                        IMEIRecord(imei: imei, deviceModel: product.name, status: 'In Stock'),
                      );
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Stock updated for ${product.name}${pendingImeis.isNotEmpty ? " (${pendingImeis.length} new IMEIs saved)" : ""}'),
                        backgroundColor: const Color(0xFFE65100),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
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

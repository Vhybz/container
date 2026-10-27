import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../core/utils.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/product_card.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/cart_provider.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/customer_provider.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/sale_model.dart';
import '../../models/product.dart';
import '../../models/customer_model.dart';
import '../../models/user_model.dart';
import '../../services/receipt_service.dart';
import '../../services/sms_service.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/pos_transaction_history_view.dart';
import '../../services/held_receipt_provider.dart';
import '../../services/birthday_service.dart';
import '../../services/branch_provider.dart';
import '../../widgets/phone_prompt_dialog.dart';
import '../../widgets/passcode_guard.dart';
import '../../widgets/tender_dialog.dart';
import '../../widgets/category_filter_rail.dart';

import '../../services/customer_metrics_provider.dart';

enum POSView { sales, history }

class CashierPOS extends ConsumerStatefulWidget {
  const CashierPOS({super.key});

  @override
  ConsumerState<CashierPOS> createState() => _CashierPOSState();
}

class _CashierPOSState extends ConsumerState<CashierPOS> {
  POSView _currentView = POSView.sales;
  String _selectedCategory = 'All';
  
  String _productSearchQuery = '';

  // Keyboard shortcut focus & search controller
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _mainKeyboardFocusNode = FocusNode();

  // Selected customer for the current sale
  Customer? _selectedCustomer;
  String? _uploadedReceiptUrl;

  static const Map<String, List<String>> allowedCatalog = {
    'PHARMACY': [
      'Amoxicillin 500mg', 'Paracetamol Extra 500mg', 'Ibuprofen 400mg',
      'Metformin 850mg', 'Omeprazole 20mg', 'Vitamin C 1000mg Chewable',
      'First Aid Kit', 'Hand Sanitizer 500ml', 'Digital Thermometer'
    ],
    'BARBERSHOP': [
      'Executive Haircut', 'Beard Grooming & Oil', 'Hair Dye / Blackening',
      'Facial Scrub & Steam', 'Kids Haircut', 'Premium Hair Gel (150g)',
      'Beard Growth Oil (50ml)'
    ],
    'PHONE & ACCESSORIES': [
      'iPhone 15 Pro 128GB', 'Samsung Galaxy S24 Ultra', 'Google Pixel 8 Pro',
      '20W USB-C Fast Charger', 'MagSafe Clear Case', '9D Curved Tempered Glass',
      'iPhone Screen Repair (Labor + Part)', 'Charging Port Repair'
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cartProvider.notifier).registerPos('/cashier');
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _mainKeyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.f2) {
      _triggerCheckoutShortcut();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.f3) {
      if (ref.read(cartProvider).isNotEmpty) {
        _holdCurrentReceipt();
      } else {
        _showHeldReceipts();
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.f4) {
      _confirmClearCartShortcut();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus == null ||
          primaryFocus == _mainKeyboardFocusNode ||
          primaryFocus.context?.widget is! EditableText) {
        _triggerCheckoutShortcut();
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _searchFocusNode.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _triggerCheckoutShortcut() {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Press F1 to search products!'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final subtotal = ref.read(cartProvider.notifier).subtotal;
    final isWholesale = ref.read(isWholesaleProvider);
    double discountPercentage = 0.0;
    String promoLabel = '';
    if (isWholesale && subtotal > 0 && cartItems.isNotEmpty) {
      final totalWeight = cartItems.fold(0.0, (sum, i) => sum + i.quantity);
      final bool isFavorite = _selectedCustomer?.isFavorite ?? false;
      if (isFavorite) {
        discountPercentage = 0.10;
        promoLabel = '${cartItems.first.product.category} - Favorite Customer Reward (10% OFF)';
      } else if (totalWeight >= 10) {
        discountPercentage = 0.05;
        promoLabel = '${cartItems.first.product.category} - Bulk Purchase Reward (5% OFF)';
      }
    }
    final discount = subtotal * discountPercentage;
    final total = subtotal - discount;
    _showPaymentDialog(total, discount, promoLabel);
  }

  void _confirmClearCartShortcut() {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Clear Cart? [F4]'),
          ],
        ),
        content: Text('Are you sure you want to remove all ${cart.length} item(s) from the current sale?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: const Text('CLEAR CART'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    // Check for Birthday
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        BirthdayService.checkAndShowBirthdayWish(context, user);
      }
    });

    // Instant Permission Guard: Redirect if access is revoked
    final roles = user.activeRoles;
    final hasAccess = roles.contains(UserRole.cashier) || roles.contains(UserRole.superAdmin) || roles.contains(UserRole.admin) || user.enabledPermissions.contains('/cashier');
    
    if (!hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final menuItems = ref.watch(menuItemsProvider);

    // Safety: Reset selected category if it no longer exists after deletions
    final productsAsync = ref.watch(productsFutureProvider);
    if (productsAsync.hasValue) {
      final products = productsAsync.value!;
      final availableCategories = ['All', ...{
        ...allowedCatalog.keys,
        ...products.where((p) => !p.isDeleted).map((p) => _getMappedCategory(p))
      }];
      if (!availableCategories.contains(_selectedCategory.toUpperCase()) && _selectedCategory != 'All') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategory = 'All');
        });
      }
    }

    return RolePopScope(
      currentRoute: '/cashier',
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentView != POSView.sales) {
            setState(() => _currentView = POSView.sales);
          } else {
            // Already on Sales (Home), stay here instead of showing exit dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Use the menu to logout or switch accounts'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: PasscodeGuard(
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: MainAppBar(
              title: _currentView == POSView.sales 
                  ? 'POS System' 
                  : 'Sales History',
              actions: [],
            ),
            drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, user, menuItems)),
            body: Focus(
              focusNode: _mainKeyboardFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) => _handleKeyEvent(event),
              child: Row(
                children: [
                  if (isDesktop) _buildSidebar(context, user, menuItems),
                  Expanded(
                    child: _currentView == POSView.sales 
                      ? _buildPOSLayout(isMobile, isDesktop)
                      : _buildHistoryLayout(),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(child: _buildFooter()),
            floatingActionButton: (isMobile && _currentView == POSView.sales)
                ? SafeArea(
                    child: FloatingActionButton.extended(
                      onPressed: () => _showMobileCart(),
                      label: const Text('View Cart'),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.shopping_cart),
                          if (ref.watch(cartProvider).isNotEmpty)
                            Positioned(
                              right: -8,
                              top: -8,
                              child: CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '${ref.watch(cartProvider).length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  )
                : null,
          ),
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
        height: MediaQuery.of(context).size.height * 0.85,
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
            Expanded(child: _buildCartSection(context, ref)),
          ],
        ),
      ),
    );
  }

  void _holdCurrentReceipt() {
    final cartItems = ref.read(cartProvider);
    final total = ref.read(cartProvider.notifier).subtotal;
    
    final saleItems = cartItems.map((item) => SaleItem(
      product: item.product,
      quantity: item.quantity,
      priceAtSale: item.priceAtSale,
      originalPrice: item.originalPrice,
    )).toList();

    // Simple mock logic for discount/promo
    ref.read(heldReceiptProvider.notifier).holdReceipt(
      saleItems, total, 0, null, _selectedCustomer?.name, _selectedCustomer?.phone
    );
    ref.read(cartProvider.notifier).clear();
    setState(() => _selectedCustomer = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt held!')));
  }

  void _showHeldReceipts() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l))),
      builder: (context) {
        final held = ref.watch(heldReceiptProvider);
        if (held.isEmpty) {
          return Container(
            height: 200,
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt_rounded, size: 48, color: theme.disabledColor),
                const SizedBox(height: 16),
                const Text('No held receipts found.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('HELD TRANSACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('${held.length} Receipts', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: held.length,
                itemBuilder: (context, index) {
                  final h = held[index];
                  final itemsPreview = h.items.take(2).map((i) => i.product.name).join(', ');
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m), side: BorderSide(color: theme.dividerColor)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Held at ${DateFormat('HH:mm:ss').format(h.timestamp)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₵${h.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(h.customerName ?? 'Walk-in', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              Icon(Icons.shopping_basket_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${h.items.length} items', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          if (itemsPreview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(itemsPreview + (h.items.length > 2 ? '...' : ''), 
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      onTap: () {
                        // Resume logic
                        ref.read(cartProvider.notifier).clear();
                        for (var item in h.items) {
                          ref.read(cartProvider.notifier).addItemWithCustomPrice(item.product, item.quantity, item.priceAtSale, item.originalPrice);
                        }
                        ref.read(heldReceiptProvider.notifier).resumeReceipt(h);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildPOSLayout(bool isMobile, bool isDesktop) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: _buildProductSection(context, ref),
          ),
        ),
        if (!isMobile)
          Container(
            width: isDesktop ? 400 : 300,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : AppColors.borderGray)),
            ),
            child: Material(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: _buildCartSection(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, UserAccount user, List<SidebarItem> menuItems) {
    const currentRoute = '/cashier';
    return AppSidebar(
      userId: user.id,
      userName: user.name,
      userRole: user.activePrimaryRole.name.toUpperCase(),
      currentRoute: currentRoute,
      items: menuItems,
      onTap: (route) => MenuService.navigate(context, route, currentRoute),
    );
  }

  Widget _buildProductSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final productsAsync = ref.watch(productsFutureProvider);
    final isWholesale = ref.watch(isWholesaleProvider);

    if (user == null) return const SizedBox.shrink();
    int crossAxisCount = ResponsiveLayout.isMobile(context) ? 2 : (ResponsiveLayout.isTablet(context) ? 3 : 4);

    final activeProds = productsAsync.value?.where((p) => !p.isDeleted).toList() ?? [];
    final Map<String, int> categoryCounts = {
      'All': activeProds.length,
    };
    for (final p in activeProds) {
      final cat = _getMappedCategory(p);
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      categoryCounts[cat.toLowerCase()] = (categoryCounts[cat.toLowerCase()] ?? 0) + 1;
      categoryCounts[cat.toUpperCase()] = (categoryCounts[cat.toUpperCase()] ?? 0) + 1;
    }

    final categories = ['All', ...{...allowedCatalog.keys, ...activeProds.map((p) => _getMappedCategory(p))}];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          _buildPOSControls(categories, categoryCounts: categoryCounts),
          const SizedBox(height: 8),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = products
                    .where((p) => !p.isDeleted)
                    .where((p) {
                      final mappedCat = _getMappedCategory(p);
                      
                      // Filter based on UI Category Selection and Search Query
                      final matchesCategory = _selectedCategory == 'All' || 
                          mappedCat.toUpperCase() == _selectedCategory.toUpperCase();
                      final matchesSearch = p.name.toLowerCase().contains(_productSearchQuery.toLowerCase()) || 
                                           p.category.toLowerCase().contains(_productSearchQuery.toLowerCase());
                      
                      return matchesCategory && matchesSearch;
                    })
                    .toList();
                
                // Sort: Highest Quantity first, then Priced items, then Natural Name sort
                filtered.sort((a, b) {
                  // 1. Quantity Priority (Descending)
                  if (a.stockQuantity != b.stockQuantity) {
                    return b.stockQuantity.compareTo(a.stockQuantity);
                  }

                  // 2. Priced Priority (Sellable items first if quantities are equal)
                  final aIsPriced = a.getPrice(isWholesale, customer: _selectedCustomer) > 0.01;
                  final bIsPriced = b.getPrice(isWholesale, customer: _selectedCustomer) > 0.01;
                  if (aIsPriced != bIsPriced) {
                    return aIsPriced ? -1 : 1;
                  }

                  // 3. Natural Name Sort (Covers weight ranges)
                  return _compareNaturally(a.name, b.name);
                });
                
                if (filtered.isEmpty) {
                  return Center(child: Text(_productSearchQuery.isEmpty ? 'No items in this category' : 'No products match "$_productSearchQuery"', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)));
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.s,
                    mainAxisSpacing: AppSpacing.s,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final mappedCat = _getMappedCategory(product);
                    final hasPromo = product.isPromoActiveFor(false, _selectedCustomer);
                    final currentPrice = product.getPrice(false, customer: _selectedCustomer);
                    final isPriced = currentPrice > 0.01;
                    
                    return ProductCard(
                      name: product.name,
                      category: mappedCat,
                      price: isPriced ? '₵${currentPrice.toStringAsFixed(2)}/${product.unit}' : 'UNPRICED',
                      originalPrice: hasPromo ? '₵${product.retailPrice.toStringAsFixed(2)}' : null,
                      stockQuantity: product.stockQuantity,
                      isUnlimited: product.isUnlimited,
                      lowStockThreshold: product.lowStockThreshold,
                      unit: product.unit,
                      promoLabel: hasPromo ? '${product.name} - ${product.discountPercentage % 1 == 0 ? product.discountPercentage.toInt() : product.discountPercentage}% OFF' : null,
                      imageUrl: product.imageUrl,
                      requiresPrescription: product.requiresPrescription,
                      requiresImei: product.requiresImei,
                      isService: product.isService,
                      batchExpiryDate: product.batchExpiryDate,
                      batchNumber: product.batchNumber,
                      onTap: isPriced ? () => _handleProductTap(product, false, currentPrice) : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('This product is not yet priced. Please contact Admin.')),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOSControls(List<String> categories, {Map<String, int>? categoryCounts}) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Column(
      children: [
        // Full-width Search Input with instant F1 shortcut badge and clear action
        SizedBox(
          height: 44,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: (v) => setState(() => _productSearchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search products by name or category... [F1]',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _productSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _productSearchQuery = '');
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text('F1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.m),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Modern Category Filter Rail with live item counts
        CategoryFilterRail(
          categories: categories,
          selectedCategory: _selectedCategory,
          categoryCounts: categoryCounts,
          onSelectCategory: (cat) => setState(() {
            _selectedCategory = cat;
            _productSearchQuery = '';
          }),
        ),
        if (!isMobile) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildShortcutPill('F1', 'Search'),
                const SizedBox(width: 8),
                _buildShortcutPill('F2 / Space', 'Checkout'),
                const SizedBox(width: 8),
                _buildShortcutPill('F3', 'Hold Bill'),
                const SizedBox(width: 8),
                _buildShortcutPill('F4', 'Clear Cart'),
                const SizedBox(width: 8),
                _buildShortcutPill('Esc', 'Unfocus'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShortcutPill(String keyLabel, String actionLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              keyLabel,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 5),
          Text(actionLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleProductTap(Product product, bool isWholesale, double currentPrice) {
    if (product.isExpired) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.dangerous_rounded, color: Colors.red, size: 48),
          title: const Text('Safety Quarantine: Expired Item', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
                child: Text(
                  'This item cannot be sold or dispensed because its expiration date has passed. Please immediately remove batch "${product.batchNumber ?? "N/A"}" from the shelf.',
                  style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood / Quarantine Item', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final String u = product.unit.toLowerCase();
    final bool isPiece = u == 'pcs' || u == 'unit' || u == 'service' || u == 'box' || u == 'bottle' || product.isService;
    
    if (isPiece) {
      final originalPrice = isWholesale ? product.wholesalePrice : product.retailPrice;
      ref.read(cartProvider.notifier).addItemWithCustomPrice(product, 1.0, currentPrice, originalPrice);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showWeightInputDialog(product);
    }
  }

  void _showWeightInputDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductWeightDialog(
        product: product,
        customer: _selectedCustomer,
        onAdd: (weight, price, original) {
          ref.read(cartProvider.notifier).addItemWithCustomPrice(product, weight, price, original);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} (${WeightConverter.formatShort(weight, unit: product.unit)}) added to cart'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined),
              const SizedBox(width: 8),
              const Text('Current Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                onPressed: () => _showHeldReceipts(),
                icon: const Icon(Icons.list_alt, color: Colors.blue),
                tooltip: 'View Held Receipts [F3]',
              ),
              const Spacer(),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () => _holdCurrentReceipt(),
                  icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                  tooltip: 'Hold Receipt [F3]',
                ),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () => _confirmClearCartShortcut(),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                  tooltip: 'Clear Cart [F4]',
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Customer Selection
        Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline, size: 20),
            title: Text(_selectedCustomer?.name ?? 'Select Customer', 
              style: TextStyle(fontWeight: _selectedCustomer != null ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurface)),
            subtitle: _selectedCustomer != null ? Text(_selectedCustomer!.phone, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _selectedCustomer = null),
                    tooltip: 'Remove Customer',
                  ),
                IconButton(
                  icon: Icon(_selectedCustomer == null ? Icons.add_circle_outline : Icons.edit, size: 18),
                  onPressed: () => _showCustomerDialog(),
                ),
              ],
            ),
            onTap: () => _showCustomerDialog(),
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
                      weight: WeightConverter.formatShort(item.quantity, unit: item.product.unit, productName: item.product.name, category: item.product.category),
                      amount: '₵${item.total.toStringAsFixed(2)}',
                      onDelete: () => notifier.removeItem(index),
                      onIncrement: () => notifier.updateQuantity(index, item.quantity + 1),
                      onDecrement: () => notifier.updateQuantity(index, item.quantity - 1),
                    );
                  },
                ),
        ),
        _buildCartSummary(ref),
      ],
    );
  }

  Future<bool> _showBulkPurchaseCustomerDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: Colors.blue),
            SizedBox(width: 12),
            Text('Bulk Purchase Detected'),
          ],
        ),
        content: const Text(
          'This sale exceeds ₵800.00. For records and loyalty tracking, we need to register this as a Bulk Purchase.\n\nWould you like to select or add a customer now?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL SALE'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('PROCEED TO CUSTOMER'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showCustomerDialog({bool isBulk = false}) async {
    await showDialog(
      context: context,
      builder: (context) => CustomerSelectionDialog(
        isBulk: isBulk,
        onSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
            
            // Auto-Switch Sale Mode based on customer type
            final isWholesale = ref.read(isWholesaleProvider);
            if (customer.isWholesaler && !isWholesale) {
              // Suggest switching to wholesale or just do it?
              // For now, let's just do it to be fast, but clear the cart as required
              if (ref.read(cartProvider).isEmpty) {
                ref.read(isWholesaleProvider.notifier).state = true;
              } else {
                _showModeSwitchOnCustomerSelect(true);
              }
            } else if (!customer.isWholesaler && isWholesale) {
              if (ref.read(cartProvider).isEmpty) {
                ref.read(isWholesaleProvider.notifier).state = false;
              } else {
                _showModeSwitchOnCustomerSelect(false);
              }
            }
          });
        },
      ),
    );
  }

  void _showModeSwitchOnCustomerSelect(bool targetWholesale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${targetWholesale ? "Wholesale Account" : "Standard Account"} Detected'),
        content: Text('This customer has a ${targetWholesale ? "wholesale" : "standard"} account profile. Would you like to switch pricing mode? \n\n(This will CLEAR your current cart)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP CURRENT')),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              ref.read(isWholesaleProvider.notifier).state = targetWholesale;
              Navigator.pop(context);
            },
            child: const Text('SWITCH MODE & CLEAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider);
    final isWholesale = ref.watch(isWholesaleProvider);
    final subtotal = ref.watch(cartProvider.notifier).subtotal;

    // Promotion Logic
    double discountPercentage = 0;
    String promoLabel = '';
    
    if (isWholesale && subtotal > 0) {
      final totalWeight = cartItems.fold(0.0, (sum, item) => sum + item.quantity);
      final bool isFavorite = _selectedCustomer?.isFavorite ?? false;
      
      if (isFavorite) {
        discountPercentage = 0.10;
        promoLabel = '${cartItems.first.product.category} - Favorite Customer Reward (10% OFF)';
      } else if (totalWeight >= 10) {
        discountPercentage = 0.05;
        promoLabel = '${cartItems.first.product.category} - Bulk Purchase Reward (5% OFF)';
      }
    }

    final discount = subtotal * discountPercentage;
    final total = subtotal - discount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          if (discount > 0) ...[
            _summaryRow('Subtotal', '₵${subtotal.toStringAsFixed(2)}', fontSize: 13),
            _summaryRow(promoLabel, '-₵${discount.toStringAsFixed(2)}', color: Colors.green, fontSize: 12),
            const SizedBox(height: 8),
          ],
          _summaryRow('TOTAL DUE', '₵${total.toStringAsFixed(2)}', isBold: true, fontSize: 20, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: cartItems.isEmpty ? null : () => _showPaymentDialog(total, discount, promoLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('PROCEED TO PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('F2 / Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: cartItems.isEmpty ? null : () => _showDebtSaleDialog(total, discount, promoLabel),
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
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, 
              style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color ?? theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  void _showDebtSaleDialog(double finalTotal, double discount, String promo) async {
    // 1. Force Customer Selection if none selected
    if (_selectedCustomer == null) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.person_search, color: Colors.blue),
              SizedBox(width: 12),
              Text('Customer Required'),
            ],
          ),
          content: const Text('This is a debt sale. You must select an existing customer profile or register a new one to proceed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'), 
              child: const Text('CANCEL SALE')
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'), 
              child: const Text('REGISTER NEW')
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'select'), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('SELECT CUSTOMER')
            ),
          ],
        ),
      );

      if (choice == 'select') {
        await _showCustomerDialog();
      } else if (choice == 'new') {
        await _showCustomerRegistrationDialog();
      } else {
        return; // User canceled or dismissed
      }
    }

    // Safety: If still null after selection flow, stop.
    if (_selectedCustomer == null) return;

    // 2. Partial Payment Dialog with Change Option
    final partialPaymentController = TextEditingController();
    
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.money_off, color: Colors.orange),
              SizedBox(width: 12),
              Text('Confirm Debt Sale'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Recording debt for ${_selectedCustomer!.name}.', style: const TextStyle(fontSize: 13))),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close confirm
                      await _showCustomerDialog(); // Select new
                      _showDebtSaleDialog(finalTotal, discount, promo); // Restart flow
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('CHANGE', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total Amount: ₵${finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: partialPaymentController,
                decoration: const InputDecoration(
                  labelText: 'Partial Cash Payment (Optional)',
                  prefixText: '₵ ',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text('The balance will be saved as outstanding debt.', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final double partial = double.tryParse(partialPaymentController.text) ?? 0;
                List<PaymentDetail> payments = [];
                if (partial > 0) {
                  payments.add(PaymentDetail(
                    method: PaymentMethod.cash, 
                    amount: partial,
                  ));
                }
                Navigator.pop(context);
                _completeSale(ref, payments, finalTotal, discount, promo);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              child: const Text('CONFIRM DEBT SALE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerRegistrationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => CustomerSelectionDialog(
        isBulk: true, // Forces "New Customer" view
        onSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
          });
        },
      ),
    );
  }

  void _showPaymentDialog(double finalTotal, double discount, String promo) async {
    final cartItems = ref.read(cartProvider);

    // 1. Pharmacy Verification Check
    final hasRx = cartItems.any((item) => item.product.requiresPrescription || item.product.category.toLowerCase().contains('pharma'));
    if (hasRx) {
      final rxNoController = TextEditingController();
      final patientController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Prescription / Patient Details (Optional)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: patientController, decoration: const InputDecoration(labelText: 'Patient Name (Optional)')),
              TextField(controller: rxNoController, decoration: const InputDecoration(labelText: 'Rx Serial Number (Optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('PROCEED'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) return;
    }

    // 2. Tech / Phone IMEI Scanning Check
    String? scannedImei;
    final hasImei = cartItems.any((item) => item.product.requiresImei || item.product.category.toLowerCase().contains('phone') || item.product.category.toLowerCase().contains('device'));
    if (hasImei) {
      final imeiController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scan / Enter Device IMEI'),
          content: TextField(
            controller: imeiController,
            decoration: const InputDecoration(labelText: 'Device IMEI Number *', prefixIcon: Icon(Icons.qr_code_scanner)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                if (imeiController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('REGISTER IMEI'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) return;
      scannedImei = imeiController.text.trim();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TenderDialog(
        totalAmount: finalTotal,
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone,
        onComplete: (tenderResult) {
          setState(() => _uploadedReceiptUrl = tenderResult.receiptUrl);
          _completeSale(
            ref, 
            tenderResult.payments, 
            finalTotal, 
            discount, 
            promo,
            amountTendered: tenderResult.amountTendered,
            changeDue: tenderResult.changeDue,
            capturedImei: scannedImei,
          );
        },
      ),
    );
  }

  void _completeSale(
    WidgetRef ref, 
    List<PaymentDetail> payments, 
    double finalTotal, 
    double discount, 
    String promo, {
    double? amountTendered,
    double? changeDue,
    String? capturedImei,
  }) async {
    final cartItems = ref.read(cartProvider);
    final currentUser = ref.read(currentUserProvider);
    
    final double amountPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    final double balance = finalTotal - amountPaid;
    final double totalCost = cartItems.fold(0.0, (sum, item) => sum + (item.product.costPrice * item.quantity));

    // High Value Sale: Optionally prompt for customer, but fallback to Walk-In if skipped
    if (finalTotal >= 800 && _selectedCustomer == null) {
      final proceed = await _showBulkPurchaseCustomerDialog();
      if (proceed) {
        await _showCustomerDialog(isBulk: true);
      }
      // If customer is still not selected, default to Walk-In Customer so sale is not blocked
      _selectedCustomer ??= Customer(
        id: 'WALKIN-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Walk-In Customer',
        phone: '',
        branchCode: currentUser?.branchCode ?? 'MAIN',
      );
    }

    // Debt Enforcement: If there's a balance, a customer MUST be selected
    if (balance > 0.01 && _selectedCustomer == null) {
      final proceed = await _showDebtCustomerRequiredDialog();
      if (!proceed) return;
      
      await _showCustomerDialog();
      if (_selectedCustomer == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Credit/Debt sales require selecting or creating a customer profile.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final hasBankDeposit = payments.any((p) => p.method == PaymentMethod.bankDeposit);

    final sale = SaleRecord(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      branchCode: currentUser?.branchCode ?? 'MAIN',
      items: cartItems.map((item) {
        final itemImei = capturedImei ?? item.imei ?? (item.product.imeiList != null && item.product.imeiList!.isNotEmpty ? item.product.imeiList!.first : null);
        return SaleItem(
          product: item.product,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
          originalPrice: item.originalPrice,
          imei: itemImei,
        );
      }).toList(),
      totalAmount: finalTotal,
      totalDiscount: discount,
      totalCost: totalCost,
      appliedPromo: promo.isEmpty ? null : promo,
      payments: payments,
      timestamp: DateTime.now(),
      cashierName: currentUser != null ? '${currentUser.firstName} ${currentUser.surname}' : 'Unknown Cashier',
      cashierId: currentUser?.id ?? 'N/A',
      customerName: _selectedCustomer?.name,
      customerPhone: _selectedCustomer?.phone,
      status: hasBankDeposit ? SaleStatus.awaitingDeposit : SaleStatus.completed,
      isVerified: !hasBankDeposit, // Cash/MoMo sales are verified immediately
      bankReceiptUrl: _uploadedReceiptUrl,
      amountTendered: amountTendered,
      changeDue: changeDue,
    );

    await ref.read(saleHistoryProvider.notifier).addSale(sale);
    ref.read(cartProvider.notifier).clear();
    
    // Send SMS with branch identification
    final currentBranch = ref.read(currentBranchProvider);
    final String? branchName = currentBranch != null 
        ? '${currentBranch.name} (${currentBranch.location})' 
        : null;

    SmsService.sendReceiptSms(sale, discountAmount: discount, branchName: branchName);

    setState(() {
      _selectedCustomer = null;
      _uploadedReceiptUrl = null;
      _productSearchQuery = '';
    });

    _showPrintConfirmation(sale);
  }

  Future<bool> _showDebtCustomerRequiredDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Customer Required', 
                style: TextStyle(fontSize: ResponsiveLayout.isMobile(context) ? 18 : null),
                overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
        content: const Text(
          'This transaction has an outstanding balance (Debt). \n\n'
          'To track this debt, you must select or register a customer before completing the sale.'
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel Sale'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMaroon, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const FittedBox(
                    child: Text('Register / Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showPrintConfirmation(SaleRecord sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptSuccessDialog(
        sale: sale,
        ref: ref,
      ),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerAction(Icons.point_of_sale, 'New Sale', _currentView == POSView.sales, () => setState(() => _currentView = POSView.sales)),
          _footerAction(Icons.history, 'Transaction History', _currentView == POSView.history, () => setState(() => _currentView = POSView.history)),
        ],
      ),
    );
  }

  Widget _footerAction(IconData icon, String label, bool isSelected, VoidCallback onTap, {int? badge}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
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
          if (badge != null && badge > 0)
            Positioned(
              right: -4,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildHistoryLayout() {
    return PosTransactionHistoryView(
      onSwitchToNewSale: () => setState(() => _currentView = POSView.sales),
    );
  }



  String _getMappedCategory(Product p) {
    final cat = p.category.toUpperCase();
    final name = p.name.toUpperCase();
    if (cat.contains('HARD') || cat.contains('LAYER') || (cat.contains('CHICKEN') && name.contains('HARD'))) {
      return 'HARD CHICKEN';
    }
    if (cat.contains('SOFT') || cat.contains('BROILER') || (cat.contains('CHICKEN') && name.contains('SOFT'))) {
      return 'SOFT CHICKEN';
    }
    return cat;
  }

  int _compareNaturally(String a, String b) {
    final RegExp digitRegex = RegExp(r'(\d+\.?\d*)');
    final Match? aMatch = digitRegex.firstMatch(a);
    final Match? bMatch = digitRegex.firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final aNum = double.tryParse(aMatch.group(0)!) ?? 0;
      final bNum = double.tryParse(bMatch.group(0)!) ?? 0;
      if (aNum != bNum) return aNum.compareTo(bNum);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

class ProductWeightDialog extends StatefulWidget {
  final Product product;
  final Customer? customer;
  final Function(double weight, double price, double original) onAdd;

  const ProductWeightDialog({super.key, required this.product, this.customer, required this.onAdd});

  @override
  State<ProductWeightDialog> createState() => _ProductWeightDialogState();
}

class _ProductWeightDialogState extends State<ProductWeightDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  final _qtyController = TextEditingController(text: '1');
  final _moneyController = TextEditingController(); // NEW: For money-to-weight calculation
  WeightUnit _unit = WeightUnit.kg;
  double _weight = 1.0;
  int _quantity = 1;
  bool _isHalf = false; 

  void _toggleUnit(WeightUnit unit) {
    if (_unit == unit) return;
    setState(() {
      if (_unit != WeightUnit.unit && unit != WeightUnit.unit) {
        if (unit == WeightUnit.kg) {
          _weight = WeightConverter.toKg(_weight);
        } else {
          _weight = WeightConverter.toLb(_weight);
        }
      }
      _unit = unit;
      _weightController.text = _weight.toStringAsFixed(2);
      _moneyController.clear(); // Clear money when unit changes to avoid confusion
    });
  }

  @override
  void initState() {
    super.initState();
    final String pName = widget.product.name.toUpperCase();
    final String pCat = widget.product.category.toUpperCase();
    
    if (pName.contains('HEAD') && (pCat.contains('GOAT') || pCat.contains('SHEEP'))) {
      _unit = WeightUnit.unit;
      _weight = 1.0;
    } else {
      _unit = WeightUnit.values.firstWhere(
        (u) => u.name == widget.product.unit, 
        orElse: () => WeightUnit.kg
      );
      _weight = 1.0;
    }
    
    _weightController = TextEditingController(text: _weight.toStringAsFixed(_unit == WeightUnit.unit ? 0 : 1));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _qtyController.dispose();
    _moneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isWholeChicken = widget.product.name.contains('Whole Chicken');

    return Consumer(
      builder: (context, ref, _) {
        final isWholesale = ref.watch(isWholesaleProvider);
        final isPcs = _unit == WeightUnit.unit;
        
        final currentPrice = widget.product.getPrice(isWholesale, weight: isPcs ? 1.0 : _weight, customer: widget.customer);
        final hasPromo = widget.product.isPromoActiveFor(isWholesale, widget.customer);
        final basePrice = isWholesale ? (widget.product.wholesalePrice) : (widget.product.retailPrice);
        
        double comparisonPrice = basePrice;
        final brackets = isWholesale ? widget.product.wholesaleBrackets : widget.product.retailBrackets;
        if (!isPcs && _weight > 0 && brackets != null && brackets.isNotEmpty) {
           double kgCheck = _unit == WeightUnit.lb ? WeightConverter.toKg(_weight) : (_unit == WeightUnit.g ? WeightConverter.fromG(_weight) : _weight);
           for (var bracket in brackets) {
            if (kgCheck >= bracket.minWeight && kgCheck <= bracket.maxWeight) {
              comparisonPrice = bracket.price;
              break;
            }
          }
        }

        final double finalEffectiveQty = _isHalf ? 0.5 : _weight;
        final double finalPrice = currentPrice;
        
        double kgWeight = _weight;
        if (_unit == WeightUnit.lb) {
          kgWeight = WeightConverter.toKg(_weight);
        } else if (_unit == WeightUnit.g) {
          kgWeight = WeightConverter.fromG(_weight);
        }

        final double total = isPcs 
            ? (finalEffectiveQty * finalPrice * _quantity) 
            : (kgWeight * currentPrice * _quantity);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.product.category.toUpperCase(),
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    Text(
                      widget.product.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    
                    // MONEY INPUT (CALCULATE WEIGHT FROM PRICE)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CALCULATE FROM MONEY (₵)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _moneyController,
                            decoration: const InputDecoration(
                              hintText: 'Enter customer amount...',
                              isDense: true,
                              prefixText: '₵ ',
                              border: InputBorder.none,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                            onChanged: (v) {
                              final amount = double.tryParse(v) ?? 0;
                              if (amount > 0 && finalPrice > 0) {
                                setState(() {
                                  double calcWeight = amount / finalPrice;
                                  // Normalize to selected unit
                                  if (_unit == WeightUnit.lb) {
                                    _weight = WeightConverter.toLb(calcWeight);
                                  } else if (_unit == WeightUnit.g) {
                                    _weight = calcWeight * 1000;
                                  } else {
                                    _weight = calcWeight;
                                  }
                                  _weightController.text = _weight.toStringAsFixed(_unit == WeightUnit.unit ? 0 : 2);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    if (isWholeChicken) ...[
                      const Text('SELECT SIZE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('FULL BIRD')),
                              selected: !_isHalf,
                              onSelected: (v) => setState(() => _isHalf = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('HALF BIRD')),
                              selected: _isHalf,
                              onSelected: (v) => setState(() => _isHalf = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            const Text('SELECT UNIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            ToggleButtons(
                              constraints: const BoxConstraints(minWidth: 55, minHeight: 40),
                              isSelected: [
                                _unit == WeightUnit.kg, 
                                _unit == WeightUnit.g,
                                _unit == WeightUnit.lb,
                                _unit == WeightUnit.unit,
                              ],
                              onPressed: (index) => _toggleUnit(WeightUnit.values[index]),
                              borderRadius: BorderRadius.circular(8),
                              selectedColor: Colors.white,
                              fillColor: theme.colorScheme.primary,
                              children: const [
                                Text('kg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('g', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('lb', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('pcs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            textAlign: TextAlign.center,
                            enabled: !_isHalf,
                            decoration: InputDecoration(
                              labelText: isPcs ? 'Quantity' : 'Weight',
                              suffixText: isPcs ? 'pcs' : _unit.name,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              errorText: (isPcs ? finalEffectiveQty : kgWeight) > widget.product.stockQuantity 
                                ? 'Only ${widget.product.stockQuantity}${isPcs ? "pcs" : "kg"} available' 
                                : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            onChanged: (v) {
                              setState(() => _weight = double.tryParse(v) ?? 0);
                              _moneyController.clear(); // Clear money if manually typing weight
                            },
                            validator: (v) {
                              if (_isHalf) return null;
                              if (v == null || (double.tryParse(v) ?? 0) <= 0) return '!';
                              final val = double.tryParse(v) ?? 0;
                              final checkWeight = isPcs ? val : (_unit == WeightUnit.kg ? val : WeightConverter.toKg(val));
                              if (checkWeight > widget.product.stockQuantity) return 'Insufficient Stock';
                              return null;
                            },
                          ),
                        ),
                        if (!isPcs) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _qtyController,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                labelText: 'Packs',
                                suffixText: 'qty',
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                errorText: (kgWeight * _quantity) > widget.product.stockQuantity
                                  ? 'Exceeds total stock'
                                  : null,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => setState(() => _quantity = int.tryParse(v) ?? 1),
                              validator: (v) {
                                if (v == null || (int.tryParse(v) ?? 0) <= 0) return '!';
                                if ((kgWeight * (int.tryParse(v) ?? 1)) > widget.product.stockQuantity) return 'Exceeds stock';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    if (widget.product.stockQuantity <= 0)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('FINISHED: OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppSpacing.m),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasPromo) ...[
                              Text('₵${comparisonPrice.toStringAsFixed(2)}', 
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, decoration: TextDecoration.lineThrough, fontSize: 12)),
                              const SizedBox(width: 6),
                            ],
                            Text('₵${finalPrice.toStringAsFixed(2)}/${isPcs ? "unit" : "kg"}', 
                              style: TextStyle(color: hasPromo ? Colors.orange.shade800 : theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Text(
                          'Total: ₵${total.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: theme.colorScheme.primary),
                        ),
                        if (_isHalf)
                          const Text('(Half Bird Pricing Applied)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (widget.product.stockQuantity <= 0 || (isPcs ? finalEffectiveQty : (kgWeight * _quantity)) > widget.product.stockQuantity)
                          ? null 
                          : () {
                            if (_formKey.currentState!.validate()) {
                              final isWholesale = ref.read(isWholesaleProvider);
                              
                              // Calculate final normalized weight/qty for inventory
                              double effectiveQty = _isHalf ? 0.5 : _weight;
                              if (_unit == WeightUnit.lb && !_isHalf) {
                                effectiveQty = WeightConverter.toKg(_weight);
                              } else if (_unit == WeightUnit.g && !_isHalf) {
                                effectiveQty = WeightConverter.fromG(_weight);
                              }

                              final double actualSalePrice = widget.product.getPrice(isWholesale, weight: isPcs ? 1.0 : effectiveQty, customer: widget.customer);
                              
                              double comparisonPrice = isWholesale ? (widget.product.wholesalePrice) : (widget.product.retailPrice);
                              
                              widget.onAdd(effectiveQty * (_isHalf ? 1 : _quantity), actualSalePrice, comparisonPrice);
                              Navigator.pop(context);
                            }
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                        ),
                        child: Text(widget.product.stockQuantity <= 0 ? 'ITEM FINISHED' : 'Add to Cart', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomerSelectionDialog extends ConsumerStatefulWidget {
  final Function(Customer) onSelected;
  final bool isBulk;
  const CustomerSelectionDialog({super.key, required this.onSelected, this.isBulk = false});

  @override
  ConsumerState<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends ConsumerState<CustomerSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _locationController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late bool _isNewCustomer;
  bool _isWholesaler = false; // NEW

  @override
  void initState() {
    super.initState();
    _isNewCustomer = widget.isBulk; 
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);
    final metrics = ref.watch(customerMetricsProvider);
    final theme = Theme.of(context);

    final List<Customer> sortedCustomers = List.from(customers);
    if (_searchQuery.isEmpty) {
      // Sort by spending when not searching
      sortedCustomers.sort((a, b) {
        final spendA = metrics[a.phone]?.totalSpend ?? 0;
        final spendB = metrics[b.phone]?.totalSpend ?? 0;
        return spendB.compareTo(spendA);
      });
    }

    final filtered = sortedCustomers.where((c) => 
      c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      c.phone.contains(_searchQuery)
    ).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isNewCustomer ? 'REGISTER CUSTOMER' : 'SELECT CUSTOMER',
                      style: TextStyle(
                        color: theme.colorScheme.primary, 
                        fontSize: ResponsiveLayout.isMobile(context) ? 12 : 13, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.2
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(_isNewCustomer ? Icons.group_rounded : Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary, size: 20),
                    onPressed: () => setState(() => _isNewCustomer = !_isNewCustomer),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (!_isNewCustomer) ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                    ? const Center(child: Text('No matches found.', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Icon(c.isFavorite ? Icons.star : Icons.person,
                                  color: c.isFavorite ? Colors.orange : theme.colorScheme.primary, size: 20),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              '${c.isWholesaler ? "WHOLESALER • " : ""}${c.phone}${c.location != null ? " • ${c.location}" : ""}', 
                              style: TextStyle(fontSize: 10, color: c.isWholesaler ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, fontWeight: c.isWholesaler ? FontWeight.bold : FontWeight.normal)
                            ),
                            onTap: () {
                              widget.onSelected(c);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                ),
              ] else ...[
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Primary Phone', prefixIcon: Icon(Icons.phone_outlined)),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            validator: (v) => v!.length != 10 ? 'Invalid' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone2Controller,
                            decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(labelText: 'Location / Area', prefixIcon: Icon(Icons.location_on_outlined)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: const Text('Wholesale Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: const Text('Enable wholesale pricing tiers', style: TextStyle(fontSize: 11)),
                            value: _isWholesaler,
                            onChanged: (v) => setState(() => _isWholesaler = v),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  final user = ref.read(currentUserProvider);
                                  final String validUuid = UuidUtils.generate();

                                  final newCustomer = Customer(
                                    id: validUuid,
                                    branchCode: user?.branchCode,
                                    name: _nameController.text,
                                    phone: _phoneController.text,
                                    phone2: _phone2Controller.text.isEmpty ? null : _phone2Controller.text,
                                    location: _locationController.text,
                                    isBulkPurchaser: widget.isBulk,
                                    isWholesaler: _isWholesaler,
                                  );
                                  
                                  try {
                                    // 1. Trigger the add (now optimistic and non-blocking for network)
                                    ref.read(customerProvider.notifier).addCustomer(newCustomer);
                                    
                                    // 2. Immediately select and close dialog
                                    widget.onSelected(newCustomer);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error adding customer: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Register & Select', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('DISMISS', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class ReceiptSuccessDialog extends StatefulWidget {
  final SaleRecord sale;
  final WidgetRef ref;

  const ReceiptSuccessDialog({super.key, required this.sale, required this.ref});

  @override
  State<ReceiptSuccessDialog> createState() => _ReceiptSuccessDialogState();
}

class _ReceiptSuccessDialogState extends State<ReceiptSuccessDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        height: 520, // Compact but fits details
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('SALE SUCCESSFUL', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Digital Receipt Card
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Text('Mi CORAZON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    const Text('Digital Copy', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    if (widget.sale.balance > 0.01)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(4)),
                        child: const Text('DEBT / CREDIT SALE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    const Divider(height: 24),
                    _receiptPreviewRow('Invoice ID', widget.sale.id.substring(widget.sale.id.length - 8).toUpperCase()),
                    _receiptPreviewRow('Cashier', widget.sale.cashierName.split(' ')[0]),
                    const Divider(height: 24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.sale.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.sale.items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name, 
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('₵${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('TOTAL', 
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('₵${widget.sale.totalAmount.toStringAsFixed(2)}', 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                        ),
                      ],
                    ),
                    if (widget.sale.effectiveChange > 0.01) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHANGE DUE / RETURNED',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: 0.5),
                                ),
                                if (widget.sale.amountTendered != null)
                                  Text(
                                    'Tendered: ₵${widget.sale.amountTendered!.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                                  ),
                              ],
                            ),
                            Text(
                              '₵${widget.sale.effectiveChange.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.sale.balance > 0.01) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('AMOUNT PAID', 
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('₵${widget.sale.amountPaid.toStringAsFixed(2)}', 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('BALANCE DUE (DEBT)', 
                              style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('₵${widget.sale.balance.toStringAsFixed(2)}', 
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showReceiptOptionsDialog(widget.sale),
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                label: const Text('VIEW RECEIPT OPTIONS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('CLOSE WINDOW', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptOptionsDialog(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print Physical Receipt'),
              onTap: () {
                Navigator.pop(context);
                ReceiptService.printReceipt(sale);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Digital Receipt (PDF)'),
              onTap: () {
                Navigator.pop(context);
                ReceiptService.shareReceipt(sale);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.orange),
              title: const Text('Send SMS Confirmation'),
              onTap: () async {
                String? targetPhone = sale.customerPhone;
                if (targetPhone == null || targetPhone.isEmpty) {
                  targetPhone = await PhonePromptDialog.show(context);
                }

                if (targetPhone != null && targetPhone.isNotEmpty) {
                  final success = await SmsService.sendReceiptSms(sale, customPhone: targetPhone);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'SMS Sent' : 'SMS Failed'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _receiptPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, 
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

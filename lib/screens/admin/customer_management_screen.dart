import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../core/uuid_utils.dart';
import '../../models/customer_metrics.dart';
import '../../services/customer_metrics_provider.dart';
import '../../services/sale_provider.dart';
import '../../models/sale_model.dart';
import 'package:intl/intl.dart';
import '../../core/utils.dart';

enum CustomerSortOption {
  whatTheyComeToDo('What They Come To Do', 'Grouped by purpose / service', Icons.category_rounded),
  highestSpend('Highest Spend', '₵₵₵ → ₵', Icons.trending_up),
  mostVisits('Most Visits / Orders', 'Highest frequency', Icons.repeat),
  recentActivity('Recent Activity', 'Latest order date', Icons.schedule),
  nameAZ('Name (A – Z)', 'Alphabetical', Icons.sort_by_alpha),
  highestDebt('Highest Debt', 'Outstanding credit', Icons.money_off),
  favoritesFirst('VIPs & Favorites', 'Priority pin', Icons.star);

  final String label;
  final String subtitle;
  final IconData icon;
  const CustomerSortOption(this.label, this.subtitle, this.icon);
}

class CustomerItemTally {
  final String productName;
  final String category;
  final String unit;
  double totalQuantity;
  double totalSpent;
  int orderCount;
  DateTime lastPurchased;

  CustomerItemTally({
    required this.productName,
    required this.category,
    required this.unit,
    required this.totalQuantity,
    required this.totalSpent,
    required this.orderCount,
    required this.lastPurchased,
  });

  double get averagePrice => totalQuantity > 0 ? totalSpent / totalQuantity : 0.0;
}

class CustomerAggregateData {
  final Customer customer;
  final List<SaleRecord> sales;
  final List<CustomerItemTally> itemTallies;
  final double sumOfItems;
  final double totalSpend;
  final double totalDebt;
  final int visitCount;
  final DateTime? lastVisit;
  final String purposeCategory;
  final String primaryActivity;
  final IconData purposeIcon;

  CustomerAggregateData({
    required this.customer,
    required this.sales,
    required this.itemTallies,
    required this.sumOfItems,
    required this.totalSpend,
    required this.totalDebt,
    required this.visitCount,
    this.lastVisit,
    required this.purposeCategory,
    required this.primaryActivity,
    required this.purposeIcon,
  });
}

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  ConsumerState<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends ConsumerState<CustomerManagementScreen> {
  String _searchQuery = '';
  CustomerSortOption _selectedSort = CustomerSortOption.whatTheyComeToDo;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CustomerAggregateData _computeCustomerAggregate(
    Customer c, 
    List<SaleRecord> allSales, 
    CustomerMetric? metric
  ) {
    // Find all transaction records for this customer
    final customerSales = allSales.where((s) {
      final matchesPhone = s.customerPhone != null && 
          (s.customerPhone == c.phone || (c.phone2 != null && c.phone2!.isNotEmpty && s.customerPhone == c.phone2));
      final matchesName = s.customerName != null && s.customerName!.trim().toLowerCase() == c.name.trim().toLowerCase();
      return matchesPhone || matchesName;
    }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, CustomerItemTally> tallyMap = {};
    for (final sale in customerSales) {
      for (final item in sale.items) {
        final key = item.product.name.trim().toLowerCase();
        if (tallyMap.containsKey(key)) {
          final existing = tallyMap[key]!;
          existing.totalQuantity += item.quantity;
          existing.totalSpent += item.total;
          existing.orderCount += 1;
          if (sale.timestamp.isAfter(existing.lastPurchased)) {
            existing.lastPurchased = sale.timestamp;
          }
        } else {
          tallyMap[key] = CustomerItemTally(
            productName: item.product.name,
            category: item.product.category,
            unit: item.product.unit,
            totalQuantity: item.quantity,
            totalSpent: item.total,
            orderCount: 1,
            lastPurchased: sale.timestamp,
          );
        }
      }
    }

    final itemTallies = tallyMap.values.toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    final sumOfItems = itemTallies.fold(0.0, (acc, t) => acc + t.totalSpent);
    final totalSpend = customerSales.isNotEmpty 
        ? customerSales.fold(0.0, (acc, s) => acc + s.totalAmount) 
        : (metric?.totalSpend ?? 0.0);
    final totalDebt = customerSales.isNotEmpty 
        ? customerSales.fold(0.0, (acc, s) => acc + (s.isActive ? s.balance : 0.0)) 
        : (metric?.totalDebt ?? 0.0);
    final visitCount = customerSales.isNotEmpty ? customerSales.length : (metric?.visitCount ?? 0);
    final lastVisit = customerSales.isNotEmpty ? customerSales.first.timestamp : metric?.lastVisit;

    String purposeCategory = 'General / New';
    String primaryActivity = 'No visits recorded';
    IconData purposeIcon = Icons.person_outline;

    if (itemTallies.isNotEmpty) {
      final top = itemTallies.first;
      primaryActivity = top.productName;
      final cat = top.category.trim().toLowerCase();
      final name = top.productName.trim().toLowerCase();

      if (cat.contains('barber') || cat.contains('hair') || cat.contains('grooming') || cat.contains('service') ||
          name.contains('cut') || name.contains('fade') || name.contains('shave') || name.contains('beard') || name.contains('trim') || name.contains('dye') || name.contains('wash')) {
        purposeCategory = 'Barber & Grooming';
        purposeIcon = Icons.content_cut;
      } else if (cat.contains('pharmacy') || cat.contains('med') || cat.contains('drug') || cat.contains('health') ||
          name.contains('paracetamol') || name.contains('postnor') || name.contains('tablet') || name.contains('syrup') || name.contains('capsule') || name.contains('injection')) {
        purposeCategory = 'Pharmacy & Health';
        purposeIcon = Icons.medication_outlined;
      } else if (cat.contains('drink') || cat.contains('beverage') || cat.contains('water') || cat.contains('snack') || cat.contains('food') ||
          name.contains('water') || name.contains('coke') || name.contains('fanta') || name.contains('drink') || name.contains('malt')) {
        purposeCategory = 'Drinks & Refreshments';
        purposeIcon = Icons.local_drink_outlined;
      } else if (cat.contains('tech') || cat.contains('electronic') || cat.contains('phone') || cat.contains('cable') || cat.contains('accessory') || cat.contains('repair')) {
        purposeCategory = 'Tech & Accessories';
        purposeIcon = Icons.devices_outlined;
      } else if (top.category.trim().isNotEmpty && top.category.trim().toLowerCase() != 'general') {
        purposeCategory = top.category.trim();
        purposeIcon = Icons.inventory_2_outlined;
      } else {
        purposeCategory = 'Retail Goods';
        purposeIcon = Icons.shopping_bag_outlined;
      }
    }

    return CustomerAggregateData(
      customer: c,
      sales: customerSales,
      itemTallies: itemTallies,
      sumOfItems: sumOfItems,
      totalSpend: totalSpend,
      totalDebt: totalDebt,
      visitCount: visitCount,
      lastVisit: lastVisit,
      purposeCategory: purposeCategory,
      primaryActivity: primaryActivity,
      purposeIcon: purposeIcon,
    );
  }

  Color _getPurposeColor(String category, ThemeData theme) {
    switch (category) {
      case 'Barber & Grooming':
        return Colors.blue.shade700;
      case 'Pharmacy & Health':
        return Colors.teal.shade700;
      case 'Drinks & Refreshments':
        return Colors.orange.shade800;
      case 'Tech & Accessories':
        return Colors.purple.shade700;
      case 'Retail Goods':
        return Colors.indigo.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final customers = ref.watch(customerProvider);
    final metrics = ref.watch(customerMetricsProvider);
    final allSales = ref.watch(saleHistoryProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/customers';

    // Exclude wholesalers completely from customer directory
    final regularCustomers = customers.where((c) => !c.isWholesaler).toList();

    // Pre-calculate aggregates for all regular customers
    final List<CustomerAggregateData> allAggregates = regularCustomers.map((c) {
      final m = metrics[c.phone];
      return _computeCustomerAggregate(c, allSales, m);
    }).toList();

    // Filter customers
    final filteredAggregates = allAggregates.where((agg) {
      final c = agg.customer;
      final query = _searchQuery.trim().toLowerCase();
      
      if (query.isNotEmpty) {
        final matchesName = c.name.toLowerCase().contains(query);
        final matchesPhone = c.phone.contains(query);
        final matchesPhone2 = c.phone2?.contains(query) ?? false;
        final matchesLocation = c.location?.toLowerCase().contains(query) ?? false;
        final matchesPurpose = agg.purposeCategory.toLowerCase().contains(query) || agg.primaryActivity.toLowerCase().contains(query);
        if (!matchesName && !matchesPhone && !matchesPhone2 && !matchesLocation && !matchesPurpose) {
          return false;
        }
      }

      switch (_selectedFilter) {
        case 'Barber & Grooming':
          return agg.purposeCategory == 'Barber & Grooming';
        case 'Pharmacy & Health':
          return agg.purposeCategory == 'Pharmacy & Health';
        case 'Retail Goods':
          return agg.purposeCategory != 'Barber & Grooming' && agg.purposeCategory != 'Pharmacy & Health' && agg.itemTallies.isNotEmpty;
        case 'VIPs & Favorites':
          final m = metrics[c.phone];
          return c.isFavorite || (m?.performanceLabel == 'VIP');
        case 'With Debt':
          return agg.totalDebt > 0.01;
        case 'All':
        default:
          return true;
      }
    }).toList();

    // Apply selected sort
    switch (_selectedSort) {
      case CustomerSortOption.whatTheyComeToDo:
        filteredAggregates.sort((a, b) {
          // Put customers with no visits at the bottom
          if (a.itemTallies.isEmpty && b.itemTallies.isEmpty) {
            return a.customer.name.toLowerCase().compareTo(b.customer.name.toLowerCase());
          }
          if (a.itemTallies.isEmpty) return 1;
          if (b.itemTallies.isEmpty) return -1;

          // First group by Purpose Category
          final catCompare = a.purposeCategory.compareTo(b.purposeCategory);
          if (catCompare != 0) return catCompare;

          // Within same category, sort by specific service/item name
          final actCompare = a.primaryActivity.toLowerCase().compareTo(b.primaryActivity.toLowerCase());
          if (actCompare != 0) return actCompare;

          // Then by spend descending
          return b.totalSpend.compareTo(a.totalSpend);
        });
        break;
      case CustomerSortOption.highestSpend:
        filteredAggregates.sort((a, b) => b.totalSpend.compareTo(a.totalSpend));
        break;
      case CustomerSortOption.mostVisits:
        filteredAggregates.sort((a, b) => b.visitCount.compareTo(a.visitCount));
        break;
      case CustomerSortOption.recentActivity:
        filteredAggregates.sort((a, b) {
          if (a.lastVisit == null && b.lastVisit == null) return 0;
          if (a.lastVisit == null) return 1;
          if (b.lastVisit == null) return -1;
          return b.lastVisit!.compareTo(a.lastVisit!);
        });
        break;
      case CustomerSortOption.nameAZ:
        filteredAggregates.sort((a, b) => a.customer.name.toLowerCase().compareTo(b.customer.name.toLowerCase()));
        break;
      case CustomerSortOption.highestDebt:
        filteredAggregates.sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
        break;
      case CustomerSortOption.favoritesFirst:
        filteredAggregates.sort((a, b) {
          if (a.customer.isFavorite != b.customer.isFavorite) {
            return a.customer.isFavorite ? -1 : 1;
          }
          return b.totalSpend.compareTo(a.totalSpend);
        });
        break;
    }

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'Customer Directory'),
        drawer: isDesktop ? null : Drawer(
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, ref),
                    const SizedBox(height: AppSpacing.m),
                    _buildSearchAndSortBar(context, filteredAggregates.length),
                    const SizedBox(height: AppSpacing.l),
                    _buildCustomerGrid(context, ref, filteredAggregates),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndSortBar(BuildContext context, int totalResults) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            // Search input
            Expanded(
              flex: isMobile ? 0 : 3,
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by Name, Phone, Location or Purpose (e.g. Haircut, Paracetamol)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        }
                      ) 
                    : null,
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 0 : AppSpacing.m, height: isMobile ? AppSpacing.s : 0),
            // Sort Dropdown Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: PopupMenuButton<CustomerSortOption>(
                tooltip: 'Sort Customers',
                initialValue: _selectedSort,
                onSelected: (sort) => setState(() => _selectedSort = sort),
                itemBuilder: (context) => CustomerSortOption.values.map((opt) {
                  final isSelected = opt == _selectedSort;
                  return PopupMenuItem<CustomerSortOption>(
                    value: opt,
                    child: Row(
                      children: [
                        Icon(opt.icon, size: 18, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                              Text(opt.subtitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                      ],
                    ),
                  );
                }).toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SORT BY', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                          Text(_selectedSort.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        // Filter Chips & Result summary row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All'),
              const SizedBox(width: 8),
              _buildFilterChip('Barber & Grooming', icon: Icons.content_cut),
              const SizedBox(width: 8),
              _buildFilterChip('Pharmacy & Health', icon: Icons.medication_outlined),
              const SizedBox(width: 8),
              _buildFilterChip('Retail Goods', icon: Icons.shopping_bag_outlined),
              const SizedBox(width: 8),
              _buildFilterChip('VIPs & Favorites', icon: Icons.star),
              const SizedBox(width: 8),
              _buildFilterChip('With Debt', icon: Icons.money_off),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Showing $totalResults customer${totalResults == 1 ? "" : "s"} • Sorted by ${_selectedSort.label}',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    final isSelected = _selectedFilter == label;
    final theme = Theme.of(context);
    return FilterChip(
      selected: isSelected,
      avatar: icon != null ? Icon(icon, size: 14, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant) : null,
      label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      onSelected: (val) => setState(() => _selectedFilter = label),
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    
    return Flex(
      direction: isMobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Directory', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            Text('Retail and service customer directory sorted by purpose & activity', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        if (isMobile) const SizedBox(height: AppSpacing.m),
        ElevatedButton.icon(
          onPressed: () => _showAddCustomerDialog(context, ref),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Customer', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerGrid(BuildContext context, WidgetRef ref, List<CustomerAggregateData> aggregates) {
    final theme = Theme.of(context);
    final metrics = ref.watch(customerMetricsProvider);
    
    if (aggregates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40), 
          child: Text(
            _searchQuery.isEmpty ? 'No customers match the active filter.' : 'No customers match your search.', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1250 ? 4 : (constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
      final double childAspectRatio = crossAxisCount == 4
          ? 1.25
          : (crossAxisCount == 3 ? 1.40 : (crossAxisCount == 2 ? 1.65 : 2.20));

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: aggregates.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: childAspectRatio,
        ),
        itemBuilder: (context, index) {
          final agg = aggregates[index];
          final c = agg.customer;
          final m = metrics[c.phone];

          return Card(
            elevation: c.isFavorite ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              side: c.isFavorite 
                  ? BorderSide(color: Colors.orange.withValues(alpha: 0.6), width: 1.2) 
                  : BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.m),
              onTap: () => _showCustomerActivityDialog(context, agg, m),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Avatar, Name, Purpose category badge, and Options Menu
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: c.isFavorite 
                              ? Colors.orange.withValues(alpha: 0.15) 
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(
                            c.isFavorite ? Icons.star : Icons.person, 
                            color: c.isFavorite ? Colors.orange : theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _getPurposeColor(agg.purposeCategory, theme).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(agg.purposeIcon, size: 10, color: _getPurposeColor(agg.purposeCategory, theme)),
                                    const SizedBox(width: 4),
                                    Text(
                                      agg.purposeCategory.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: _getPurposeColor(agg.purposeCategory, theme),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (val) {
                            if (val == 'fav') {
                              ref.read(customerProvider.notifier).toggleFavorite(c.id);
                            } else if (val == 'edit') {
                              _showEditCustomerDialog(context, ref, c);
                            } else if (val == 'del') {
                              _confirmDeleteCustomer(context, ref, c);
                            } else if (val == 'history') {
                              _showCustomerActivityDialog(context, agg, m);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'fav', child: Text(c.isFavorite ? 'Remove Favorite' : 'Mark as Favorite')),
                            const PopupMenuItem(value: 'history', child: Text('View Full Activity & Ledger')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
                            const PopupMenuItem(value: 'del', child: Text('Delete Record', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Concise Contact & Visits Metadata Line
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 11, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(c.phone, style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant)),
                        if (c.location != null && c.location!.isNotEmpty) ...[
                          Text(' • ', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          Flexible(
                            child: Text(
                              c.location!,
                              style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        Text(' • ', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                        Text(
                          '${agg.visitCount} visit${agg.visitCount == 1 ? "" : "s"}',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (agg.totalDebt > 0.01) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Outstanding Debt: ₵${agg.totalDebt.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Unified Services & Items Box with Spend Header
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                        ),
                        child: agg.itemTallies.isNotEmpty
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "SERVICES & ITEMS DONE",
                                        style: TextStyle(
                                          fontSize: 8.5, 
                                          fontWeight: FontWeight.w900, 
                                          color: _getPurposeColor(agg.purposeCategory, theme), 
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      Text(
                                        '₵${agg.totalSpend.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12.5, 
                                          fontWeight: FontWeight.w900, 
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  // Top 2 items
                                  ...agg.itemTallies.take(2).map((tally) {
                                    final formattedQty = WeightConverter.formatShort(
                                      tally.totalQuantity,
                                      unit: tally.unit,
                                      productName: tally.productName,
                                      category: tally.category,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2.5),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3.5,
                                            height: 3.5,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              '${tally.productName} ($formattedQty)',
                                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '₵${tally.totalSpent.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (agg.itemTallies.length > 2)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        '+${agg.itemTallies.length - 2} more item${agg.itemTallies.length - 2 == 1 ? "" : "s"}',
                                        style: TextStyle(fontSize: 8.5, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  'No purchase or service history yet',
                                  style: TextStyle(fontSize: 9.5, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  void _showCustomerActivityDialog(BuildContext context, CustomerAggregateData agg, CustomerMetric? metric) {
    final customer = agg.customer;
    final sales = agg.sales;
    final itemTallies = agg.itemTallies;
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      customer.isFavorite ? Icons.star : Icons.person, 
                      color: customer.isFavorite ? Colors.orange : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customer.name, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPurposeColor(agg.purposeCategory, theme).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(agg.purposeIcon, size: 10, color: _getPurposeColor(agg.purposeCategory, theme)),
                                  const SizedBox(width: 4),
                                  Text(
                                    agg.purposeCategory.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: _getPurposeColor(agg.purposeCategory, theme),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${customer.phone} • Purpose: ${agg.primaryActivity}${customer.location != null ? " • ${customer.location}" : ""}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tab Bar
              TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    text: 'Services & Items Done (${itemTallies.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    text: 'Invoices & Receipts (${sales.length})',
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? double.maxFinite : 620,
            height: 520,
            child: TabBarView(
              children: [
                // TAB 1: Services & Items Done (Summed)
                _buildItemsDoneTab(context, agg, theme),
                // TAB 2: Invoices & Receipts
                _buildReceiptsTab(context, sales, theme),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsDoneTab(BuildContext context, CustomerAggregateData agg, ThemeData theme) {
    if (agg.itemTallies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No services or products recorded yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Transactions will automatically populate here as orders are placed.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
        ),
      );
    }

    final isFullyAccounted = (agg.sumOfItems - agg.totalSpend).abs() < 0.05;

    return Column(
      children: [
        const SizedBox(height: 12),
        // Reconciliation Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: isFullyAccounted 
                  ? Colors.green.withValues(alpha: 0.4) 
                  : theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL SERVICES / ITEMS', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('${agg.itemTallies.length} Distinct', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('SUM OF ITEMS DONE', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('₵${agg.sumOfItems.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TOTAL AMOUNT SPENT', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text('₵${agg.totalSpend.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFullyAccounted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFullyAccounted ? Icons.check_circle : Icons.info_outline, 
                      size: 13, 
                      color: isFullyAccounted ? Colors.green : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFullyAccounted 
                          ? '100% of Amount Spent accounted for by services & goods' 
                          : 'Sum of items: ₵${agg.sumOfItems.toStringAsFixed(2)} • Invoiced total: ₵${agg.totalSpend.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: isFullyAccounted ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Header of list
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ITEM / SERVICE BREAKDOWN',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.4),
              ),
              Text(
                'LINE TOTAL & SHARE',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // List of items
        Expanded(
          child: ListView.separated(
            itemCount: agg.itemTallies.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final t = agg.itemTallies[idx];
              final percent = agg.totalSpend > 0 ? (t.totalSpent / agg.totalSpend) : 0.0;
              final formattedQty = WeightConverter.formatShort(
                t.totalQuantity,
                unit: t.unit,
                productName: t.productName,
                category: t.category,
              );

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            '#${idx + 1}',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      t.productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (t.category.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        t.category.toUpperCase(),
                                        style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Total Done: $formattedQty across ${t.orderCount} order${t.orderCount == 1 ? "" : "s"} • Avg ₵${t.averagePrice.toStringAsFixed(2)} / unit',
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₵${t.totalSpent.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                            ),
                            Text(
                              '${(percent * 100).toStringAsFixed(1)}% of spend',
                              style: TextStyle(fontSize: 9.5, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percent.clamp(0.0, 1.0),
                        minHeight: 3.5,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptsTab(BuildContext context, List<SaleRecord> sales, ThemeData theme) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 42, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('No activity records found for this customer.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      itemCount: sales.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final s = sales[index];
        final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(s.timestamp);

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(dateStr, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ),
                      const SizedBox(width: 8),
                      Text('Served by ${s.cashierName}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  Text('₵${s.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ...s.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${it.product.name} (${WeightConverter.formatShort(it.quantity, unit: it.product.unit, productName: it.product.name, category: it.product.category)} @ ₵${it.priceAtSale.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('₵${it.total.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }),
              if (s.payments.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Paid via: ${s.payments.map((p) => p.method.name.toUpperCase()).join(", ")}',
                  style: TextStyle(fontSize: 9.5, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteCustomer(BuildContext context, WidgetRef ref, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Are you sure you want to remove ${customer.name} from the directory? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(customerProvider.notifier).deleteCustomer(customer.id);
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${customer.name} deleted successfully.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final phone2Controller = TextEditingController(text: customer.phone2 ?? '');
    final locationController = TextEditingController(text: customer.location ?? '');
    bool isFavorite = customer.isFavorite;
    bool isBulkPurchaser = customer.isBulkPurchaser;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text('Edit Customer: ${customer.name}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController, 
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController, 
                    decoration: const InputDecoration(labelText: 'Primary Phone', hintText: '10 digits', prefixIcon: Icon(Icons.phone_outlined)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Exactly 10 digits required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phone2Controller, 
                    decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController, 
                    decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Favorite'),
                    subtitle: const Text('Highlighted in directory'),
                    value: isFavorite,
                    onChanged: (val) => setState(() => isFavorite = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Bulk Purchaser'),
                    subtitle: const Text('Regular bulk buyer status'),
                    value: isBulkPurchaser,
                    onChanged: (val) => setState(() => isBulkPurchaser = val ?? false),
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final updatedCustomer = customer.copyWith(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    phone2: phone2Controller.text.trim().isEmpty ? null : phone2Controller.text.trim(),
                    location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    isFavorite: isFavorite,
                    isBulkPurchaser: isBulkPurchaser,
                    isWholesaler: false,
                  );
                  
                  try {
                    await ref.read(customerProvider.notifier).updateCustomer(updatedCustomer);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer details updated!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating customer: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final phone2Controller = TextEditingController();
    final locationController = TextEditingController();
    bool isFavorite = false;
    bool isBulkPurchaser = false;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Text('Add Regular Customer'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController, 
                    decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController, 
                    decoration: const InputDecoration(labelText: 'Primary Phone', hintText: '10 digits', prefixIcon: Icon(Icons.phone_outlined)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Exactly 10 digits required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phone2Controller, 
                    decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)), 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController, 
                    decoration: const InputDecoration(labelText: 'Location / Address', prefixIcon: Icon(Icons.location_on_outlined)),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Mark as Favorite'),
                    subtitle: const Text('Highlighted in directory'),
                    value: isFavorite,
                    onChanged: (val) => setState(() => isFavorite = val ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Bulk Purchaser'),
                    subtitle: const Text('Regular bulk buyer status'),
                    value: isBulkPurchaser,
                    onChanged: (val) => setState(() => isBulkPurchaser = val ?? false),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final uniqueUuid = UuidUtils.generate();

                  final newCustomer = Customer(
                    id: uniqueUuid,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    phone2: phone2Controller.text.trim().isEmpty ? null : phone2Controller.text.trim(),
                    location: locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                    isFavorite: isFavorite,
                    isBulkPurchaser: isBulkPurchaser,
                    isWholesaler: false,
                  );
                  
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    await ref.read(customerProvider.notifier).addCustomer(newCustomer);
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      Navigator.pop(context); // Pop dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Customer saved and welcome SMS sent!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Pop loading
                      String errorMessage = 'Failed to save customer';
                      final String errorStr = e.toString().toLowerCase();
                      
                      if (errorStr.contains('unique') || errorStr.contains('already exists')) {
                        errorMessage = 'A customer with phone ${phoneController.text} already exists.';
                      } else {
                        errorMessage = 'Error: $e';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMessage, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
                      );
                      debugPrint('CUSTOMER SAVE ERROR: $e');
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: const Text('Save Customer'),
            ),
          ],
        ),
      ),
    );
  }
}

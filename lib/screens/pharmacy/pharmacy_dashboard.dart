import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../models/sale_model.dart';
import '../../models/product.dart';
import '../../services/user_provider.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/menu_service.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';

class PharmacyDashboard extends ConsumerStatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  ConsumerState<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends ConsumerState<PharmacyDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/pharmacy';
    final menuItems = ref.watch(menuItemsProvider);

    // Live Data Providers
    final productsAsync = ref.watch(productsFutureProvider);
    final sales = ref.watch(saleHistoryProvider);

    final allProducts = productsAsync.value ?? [];
    final pharmacyProducts = allProducts.where((p) => !p.isDeleted && (
      p.requiresPrescription ||
      p.category.toUpperCase().contains('PHARM') ||
      p.category.toUpperCase().contains('DRUG') ||
      p.category.toUpperCase().contains('MED') ||
      p.category.toUpperCase().contains('ANTIBIOTIC') ||
      p.category.toUpperCase().contains('ANTIMALARIAL') ||
      p.category.toUpperCase().contains('ANALGESIC') ||
      p.category.toUpperCase().contains('NSAID') ||
      p.category.toUpperCase().contains('COUGH') ||
      p.category.toUpperCase().contains('COLD') ||
      p.category.toUpperCase().contains('CARDIOVASCULAR') ||
      p.category.toUpperCase().contains('GASTRO') ||
      p.category.toUpperCase().contains('CONTRACEPTIVE') ||
      p.category.toUpperCase().contains('SUPPLEMENT') ||
      p.category.toUpperCase().contains('TOPICAL') ||
      p.category.toUpperCase().contains('SEDATIVE') ||
      p.category.toUpperCase().contains('GENERAL MEDICATION')
    )).toList();

    // Today's Pharmacy Sales
    final now = DateTime.now();
    final todayPharmSales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day && s.isActive;
      final isPharm = s.items.any((i) {
        final cat = i.product.category.toUpperCase();
        return i.product.requiresPrescription || cat.contains('PHARM') || cat.contains('DRUG') || cat.contains('MED') || cat.contains('ANTIBIOTIC') || cat.contains('ANTIMALARIAL') || cat.contains('ANALGESIC') || cat.contains('NSAID') || cat.contains('SUPPLEMENT');
      });
      return isToday && isPharm;
    }).toList();

    final double todayPharmRevenue = todayPharmSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final int todayRxCount = todayPharmSales.length;

    // Expiring / Low Stock Count
    final expiringLowStockCount = pharmacyProducts.where((p) {
      final isLow = p.stockQuantity <= p.lowStockThreshold;
      final isNearExpiry = p.batchExpiryDate != null && p.batchExpiryDate!.difference(now).inDays <= 60;
      return isLow || isNearExpiry;
    }).length;

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Emmanuel Chemist - Pharmacy Operations'),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  userId: user?.id ?? '',
                  userName: user?.name ?? 'Pharmacist',
                  userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'PHARMACIST',
                  currentRoute: currentRoute,
                  items: menuItems,
                  onTap: (route) => MenuService.navigate(context, route, currentRoute),
                ),
              ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user?.id ?? '',
                userName: user?.name ?? 'Pharmacist',
                userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'PHARMACIST',
                currentRoute: currentRoute,
                items: menuItems,
                onTap: (route) => MenuService.navigate(context, route, currentRoute),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Official Pharmacy Address Header Banner
                    Card(
                      color: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.local_pharmacy, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'EMMANUEL CHEMIST',
                                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Location: Opposite Kaabere Main Clinic • GPS: BJ 0003-5661 • Email: ea0005917@gmail.com',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/pharmacy/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN PHARMACY POS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Prescriptions Today', todayRxCount.toString(), Icons.receipt_long, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Expiring / Low Stock', '$expiringLowStockCount Items', Icons.warning_amber, expiringLowStockCount > 0 ? Colors.orange : Colors.green)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Rx Revenue Today', currencyFormat.format(todayPharmRevenue), Icons.payments, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Drug Inventory & Lot Expiry'),
                        Tab(icon: Icon(Icons.description_outlined), text: 'Dispensing & Rx Logs'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBatchTrackingTab(theme, pharmacyProducts),
                          _buildPrescriptionsTab(theme, todayPharmSales),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchTrackingTab(ThemeData theme, List<Product> pharmacyProducts) {
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Drug Catalog & Expiration Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/admin/stock'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add / Intake Drug Stock'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: pharmacyProducts.isEmpty
                  ? const Center(child: Text('No pharmaceutical drugs currently in inventory.'))
                  : ListView.separated(
                      itemCount: pharmacyProducts.length,
                      separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                      itemBuilder: (context, index) {
                        final p = pharmacyProducts[index];
                        final isExpired = p.batchExpiryDate != null && p.batchExpiryDate!.isBefore(now);
                        final isNear = p.batchExpiryDate != null && !isExpired && p.batchExpiryDate!.difference(now).inDays <= 60;
                        final String statusText = isExpired ? 'Expired' : (isNear ? 'Expiring Soon' : 'Normal');
                        final String expiryText = p.batchExpiryDate != null ? DateFormat('yyyy-MM-dd').format(p.batchExpiryDate!) : 'No Date Set';
                        final String batchText = p.batchNumber != null && p.batchNumber!.isNotEmpty ? 'Batch: ${p.batchNumber}' : 'Batch: Default';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isExpired
                                ? Colors.red.withValues(alpha: 0.1)
                                : (isNear ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                            child: Icon(
                              isExpired ? Icons.cancel : (isNear ? Icons.access_time : Icons.check_circle),
                              color: isExpired ? Colors.red : (isNear ? Colors.orange : Colors.green),
                            ),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$batchText • Category: ${p.category}\nExpiry: $expiryText'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Stock: ${p.stockQuantity.toInt()} ${p.unit}', style: TextStyle(fontWeight: FontWeight.bold, color: p.stockQuantity == 0 ? Colors.red : Colors.black)),
                              Chip(
                                label: Text(statusText, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: isExpired ? Colors.red : (isNear ? Colors.orange : Colors.green),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionsTab(ThemeData theme, List<SaleRecord> todayPharmSales) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Pharmacy Dispensing Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/pharmacy/pos'),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Dispense at Pharmacy POS'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: todayPharmSales.isEmpty
                  ? const Center(child: Text('No dispensing records recorded today.'))
                  : ListView.separated(
                      itemCount: todayPharmSales.length,
                      separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                      itemBuilder: (context, index) {
                        final sale = todayPharmSales[index];
                        final itemsText = sale.items.map((i) => '${i.product.name} (x${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity})').join(', ');

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF2E7D32),
                            child: Icon(Icons.medical_information, color: Colors.white),
                          ),
                          title: Text('Invoice ${sale.id} - ${sale.customerName ?? "Walk-In Patient"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Dispensed By: ${sale.cashierName}\nDate: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.timestamp)}\nItems: $itemsText'),
                          trailing: Text(
                            currencyFormat.format(sale.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

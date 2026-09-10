import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/user_provider.dart';
import '../../services/menu_service.dart';
import '../../services/repair_ticket_provider.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/role_pop_scope.dart';

class TechShopDashboard extends ConsumerStatefulWidget {
  const TechShopDashboard({super.key});

  @override
  ConsumerState<TechShopDashboard> createState() => _TechShopDashboardState();
}

class _TechShopDashboardState extends ConsumerState<TechShopDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  // Live Repair Tickets Work Orders List
  final List<Map<String, dynamic>> _repairTickets = [
    {
      'ticketId': 'REP-1021',
      'customer': 'Emmanuel Ofori',
      'phone': '0249876543',
      'device': 'iPhone 13',
      'issue': 'Screen Replacement & Battery Replacement',
      'status': 'In Progress',
      'cost': 1200.0,
      'date': '2026-09-07'
    },
    {
      'ticketId': 'REP-1022',
      'customer': 'Sarkodie A.',
      'phone': '0201234567',
      'device': 'Samsung Note 20',
      'issue': 'Charging Port Solder Repair',
      'status': 'Ready for Pickup',
      'cost': 350.0,
      'date': '2026-09-06'
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateWorkOrderDialog(BuildContext context) {
    final customerController = TextEditingController();
    final phoneController = TextEditingController();
    final deviceController = TextEditingController();
    final issueController = TextEditingController();
    final costController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.construction_outlined, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('New Repair Work Order'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: customerController,
                decoration: const InputDecoration(labelText: 'Customer Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: deviceController,
                decoration: const InputDecoration(labelText: 'Device Model (e.g. iPhone 14 Pro)', prefixIcon: Icon(Icons.smartphone_outlined)),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: issueController,
                decoration: const InputDecoration(labelText: 'Reported Issue / Repair Description', prefixIcon: Icon(Icons.build_outlined)),
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Estimated Repair Cost (GHS)', prefixIcon: Icon(Icons.monetization_on_outlined), prefixText: '₵ '),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (customerController.text.trim().isEmpty || deviceController.text.trim().isEmpty) return;
              ref.read(repairTicketProvider.notifier).addWorkOrder(
                customer: customerController.text.trim(),
                phone: phoneController.text.trim(),
                device: deviceController.text.trim(),
                issue: issueController.text.trim().isEmpty ? 'General Hardware Service' : issueController.text.trim(),
                cost: double.tryParse(costController.text) ?? 250.0,
                deposit: 0.0,
                technician: 'Tech Specialist',
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Repair Ticket created for ${customerController.text.trim()}')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            child: const Text('CREATE TICKET'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/tech';
    final menuItems = ref.watch(menuItemsProvider);

    // Live Data Providers
    final productsAsync = ref.watch(productsFutureProvider);
    final sales = ref.watch(saleHistoryProvider);

    final allProducts = productsAsync.value ?? [];
    final techProducts = allProducts.where((p) => !p.isDeleted && (
      p.requiresImei ||
      p.category.toUpperCase().contains('PHONE') ||
      p.category.toUpperCase().contains('SMART') ||
      p.category.toUpperCase().contains('CHARGER') ||
      p.category.toUpperCase().contains('CASE') ||
      p.category.toUpperCase().contains('AUDIO') ||
      p.category.toUpperCase().contains('WEARABLE') ||
      p.category.toUpperCase().contains('ACCESSOR') ||
      p.category.toUpperCase().contains('REPAIR')
    )).toList();

    // Today's Sales & Warranties Calculation
    final now = DateTime.now();
    final todaySales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day;
      final isTech = s.items.any((item) => 
        item.product.requiresImei ||
        item.product.category.toUpperCase().contains('PHONE') ||
        item.product.category.toUpperCase().contains('SMART') ||
        item.product.category.toUpperCase().contains('ACCESSOR')
      );
      return isToday && isTech;
    }).toList();

    final double todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalDeviceUnits = techProducts.where((p) => p.requiresImei).fold(0.0, (sum, p) => sum + p.stockQuantity);

    // Digital Warranties Derived from Completed Tech Sales
    final List<Map<String, dynamic>> warrantyList = sales.where((s) => s.items.any((i) => i.product.requiresImei)).map((s) {
      final item = s.items.firstWhere((i) => i.product.requiresImei);
      return {
        'warrantyId': 'WAR-${s.id.substring(s.id.length - 6)}',
        'customer': s.customerName ?? 'Retail Client',
        'device': item.product.name,
        'imei': item.product.imeiList?.isNotEmpty == true ? item.product.imeiList!.first : 'IMEI Tracked',
        'issuedDate': DateFormat('yyyy-MM-dd').format(s.timestamp),
        'expiryDate': DateFormat('yyyy-MM-dd').format(s.timestamp.add(const Duration(days: 365))),
        'status': 'Active (12 Months)',
      };
    }).toList();

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Phone & Accessories Operations'),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  userId: user?.id ?? '',
                  userName: user?.name ?? 'Tech Rep',
                  userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'TECH REP',
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
                userName: user?.name ?? 'Tech Rep',
                userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'TECH REP',
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
                    // Banner
                    Card(
                      color: const Color(0xFFE65100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.phone_android, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Tech POS & Device Operations',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Sell devices with IMEI tracking, accessories, repair work orders & digital warranty issuance',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/tech/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN TECH POS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFE65100),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // Stat Cards
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Devices in Stock', '${totalDeviceUnits.toInt()} Units', Icons.smartphone, Colors.orange)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Active Repairs', '${_repairTickets.where((t) => t['status'] != 'Completed').length} Tickets', Icons.build_outlined, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Today\'s Revenue', currencyFormat.format(todayRevenue), Icons.monetization_on, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.qr_code), text: 'IMEI & Device Stock'),
                        Tab(icon: Icon(Icons.handyman_outlined), text: 'Repairs & Work Orders'),
                        Tab(icon: Icon(Icons.verified_user_outlined), text: 'Warranties Issued'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildImeiStockTab(theme, techProducts),
                          _buildRepairsTab(theme),
                          _buildWarrantiesTab(theme, warrantyList),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImeiStockTab(ThemeData theme, List<Product> techProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: techProducts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.smartphone_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No phone or tech products found in catalog.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/admin/stock'),
                      child: const Text('Add Tech Items in Master Stock Control'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: techProducts.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final p = techProducts[index];
                  final imeiDisplay = p.imeiList != null && p.imeiList!.isNotEmpty 
                      ? 'IMEIs Tracked: ${p.imeiList!.join(", ")}' 
                      : (p.requiresImei ? 'IMEI Tracking Enabled' : 'Standard Accessories');

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.1),
                      child: Icon(p.requiresImei ? Icons.phone_iphone : Icons.headphones_outlined, color: const Color(0xFFE65100)),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Category: ${p.category} • $imeiDisplay\nStock Quantity: ${p.isUnlimited ? "Unlimited" : "${p.stockQuantity.toInt()} ${p.unit}"}'),
                    trailing: Text(currencyFormat.format(p.retailPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildRepairsTab(ThemeData theme) {
    final tickets = ref.watch(repairTicketProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Phone Repair Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => _showCreateWorkOrderDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Work Order'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: tickets.isEmpty
                  ? const Center(child: Text('No repair tickets created yet.'))
                  : ListView.separated(
                      itemCount: tickets.length,
                      separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                      itemBuilder: (context, index) {
                        final w = tickets[index];
                        final isReady = w.status == 'Ready for Pickup';
                        final isCompleted = w.status == 'Delivered' || w.status == 'Completed';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCompleted 
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (isReady ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                            child: Icon(
                              isCompleted ? Icons.check_circle : (isReady ? Icons.mark_chat_read : Icons.construction),
                              color: isCompleted ? Colors.grey : (isReady ? Colors.green : Colors.orange),
                            ),
                          ),
                          title: Text('${w.id} - ${w.device} (${w.customer})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Issue: ${w.issue}\nDate: ${DateFormat('yyyy-MM-dd').format(w.timestamp)} • Contact: ${w.phone.isNotEmpty ? w.phone : "N/A"}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'ready') {
                                ref.read(repairTicketProvider.notifier).updateStatus(w.id, 'Ready for Pickup');
                              } else if (action == 'complete') {
                                ref.read(repairTicketProvider.notifier).updateStatus(w.id, 'Delivered');
                              } else if (action == 'remove') {
                                ref.read(repairTicketProvider.notifier).deleteTicket(w.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'ready', child: Text('Mark Ready for Pickup')),
                              const PopupMenuItem(value: 'complete', child: Text('Mark Delivered / Completed')),
                              const PopupMenuItem(value: 'remove', child: Text('Delete Ticket', style: TextStyle(color: Colors.red))),
                            ],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(currencyFormat.format(w.cost), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Chip(
                                  label: Text(w.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  backgroundColor: isCompleted ? Colors.grey : (isReady ? Colors.green : Colors.orange),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
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

  Widget _buildWarrantiesTab(ThemeData theme, List<Map<String, dynamic>> warrantyList) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: warrantyList.isEmpty
            ? const Center(child: Text('No device warranties issued from completed sales yet.'))
            : ListView.separated(
                itemCount: warrantyList.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final w = warrantyList[index];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.verified, color: Colors.white)),
                    title: Text('${w['warrantyId']} - ${w['device']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Client: ${w['customer']} • IMEI: ${w['imei']}\nValid: ${w['issuedDate']} to ${w['expiryDate']}'),
                    trailing: const Chip(
                      label: Text('Active (12 Mos)', style: TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

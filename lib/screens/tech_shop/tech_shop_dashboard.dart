import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/user_provider.dart';
import '../../services/menu_service.dart';
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

  final List<Map<String, dynamic>> _devices = [
    {'model': 'iPhone 15 Pro 128GB', 'imei': '354892109283120', 'condition': 'Brand New', 'price': 14500.0, 'warranty': '12 Months'},
    {'model': 'Samsung Galaxy S24 Ultra', 'imei': '869201948210394', 'condition': 'Brand New', 'price': 15200.0, 'warranty': '12 Months'},
    {'model': 'Google Pixel 8 Pro', 'imei': '352910482019481', 'condition': 'Refurbished Grade A', 'price': 8500.0, 'warranty': '6 Months'},
    {'model': 'AirPods Pro 2nd Gen', 'serial': 'GX9201938210', 'condition': 'Brand New', 'price': 2800.0, 'warranty': '6 Months'},
  ];

  final List<Map<String, dynamic>> _workOrders = [
    {'ticketId': 'REP-1021', 'customer': 'Emmanuel Ofori', 'device': 'iPhone 13', 'issue': 'Screen Replacement & Battery', 'status': 'In Progress', 'cost': 1200.0},
    {'ticketId': 'REP-1022', 'customer': 'Sarkodie A.', 'device': 'Samsung Note 20', 'issue': 'Charging Port Solder', 'status': 'Ready for Pickup', 'cost': 350.0},
    {'ticketId': 'REP-1023', 'customer': 'Gladys Yeboah', 'device': 'iPad Air 4', 'issue': 'Glass Digitizer Crack', 'status': 'Pending Parts', 'cost': 850.0},
  ];

  final List<Map<String, dynamic>> _warranties = [
    {'warrantyId': 'WAR-8812', 'customer': 'Emmanuel Ofori', 'device': 'iPhone 15 Pro', 'imei': '354892109283120', 'issuedDate': '2026-09-01', 'expiryDate': '2027-09-01', 'status': 'Active'},
    {'warrantyId': 'WAR-8813', 'customer': 'Abena Darko', 'device': 'AirPods Pro 2', 'serial': 'GX9201938210', 'issuedDate': '2026-03-15', 'expiryDate': '2026-09-15', 'status': 'Expiring Soon'},
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/tech';
    final menuItems = ref.watch(menuItemsProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Phone & Accessories Operations'),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  userId: user?.id ?? '',
                  userName: user?.name ?? 'Phone Sales Guy',
                  userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'PHONE SALES GUY',
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
                userName: user?.name ?? 'Phone Sales Guy',
                userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'PHONE SALES GUY',
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
                    Card(
                      color: const Color(0xFFE65100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    'Tech POS & Warranty Issuance',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Sell devices with IMEI tracking, accessories, repair work orders & generate digital warranties',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/tech/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN POS'),
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
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Devices in Stock', '28 Units', Icons.smartphone, Colors.orange)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Active Repairs', '3 Tickets', Icons.build_outlined, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Sales Revenue', currencyFormat.format(29700.00), Icons.monetization_on, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
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
                      height: 480,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildImeiStockTab(theme),
                          _buildRepairsTab(theme),
                          _buildWarrantiesTab(theme),
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

  Widget _buildImeiStockTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: ListView.separated(
          itemCount: _devices.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final d = _devices[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.phone_iphone)),
              title: Text(d['model'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('IMEI/Serial: ${d['imei'] ?? d['serial']} • Condition: ${d['condition']}\nWarranty Terms: ${d['warranty']}'),
              trailing: Text(currencyFormat.format(d['price']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRepairsTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Phone Repair Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Create Work Order'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: ListView.separated(
                itemCount: _workOrders.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final w = _workOrders[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.construction)),
                    title: Text('${w['ticketId']} - ${w['device']} (${w['customer']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Issue: ${w['issue']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(currencyFormat.format(w['cost']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Chip(
                          label: Text(w['status'], style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: w['status'] == 'Ready for Pickup' ? Colors.green : Colors.orange,
                          visualDensity: VisualDensity.compact,
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

  Widget _buildWarrantiesTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: ListView.separated(
          itemCount: _warranties.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final w = _warranties[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.verified)),
              title: Text('${w['warrantyId']} - ${w['device']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Customer: ${w['customer']} • IMEI: ${w['imei'] ?? w['serial']}\nValid: ${w['issuedDate']} to ${w['expiryDate']}'),
              trailing: Chip(
                label: Text(w['status'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                backgroundColor: w['status'] == 'Active' ? Colors.green : Colors.orange,
              ),
            );
          },
        ),
      ),
    );
  }
}

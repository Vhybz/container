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

class BarbershopDashboard extends ConsumerStatefulWidget {
  const BarbershopDashboard({super.key});

  @override
  ConsumerState<BarbershopDashboard> createState() => _BarbershopDashboardState();
}

class _BarbershopDashboardState extends ConsumerState<BarbershopDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  final List<Map<String, dynamic>> _services = [
    {'name': 'Executive Haircut', 'price': 50.0, 'duration': '30 mins', 'commissionRate': '40%'},
    {'name': 'Beard Grooming & Oil', 'price': 30.0, 'duration': '20 mins', 'commissionRate': '40%'},
    {'name': 'Hair Dye / Blackening', 'price': 45.0, 'duration': '35 mins', 'commissionRate': '35%'},
    {'name': 'Facial Scrub & Steam', 'price': 60.0, 'duration': '40 mins', 'commissionRate': '45%'},
    {'name': 'Kids Haircut', 'price': 30.0, 'duration': '20 mins', 'commissionRate': '40%'},
  ];

  final List<Map<String, dynamic>> _queue = [
    {'id': 'Q-01', 'customer': 'Kofi Badu', 'service': 'Executive Haircut', 'barber': 'Master Barber Frank', 'status': 'In Service', 'time': '10:15 AM'},
    {'id': 'Q-02', 'customer': 'Yaw Boateng', 'service': 'Beard Grooming', 'barber': 'Barber Alex', 'status': 'Waiting', 'time': '10:30 AM'},
    {'id': 'Q-03', 'customer': 'Nana K.', 'service': 'Facial Scrub & Haircut', 'barber': 'Master Barber Frank', 'status': 'Scheduled', 'time': '11:00 AM'},
  ];

  final List<Map<String, dynamic>> _commissions = [
    {'barber': 'Master Barber Frank', 'totalCuts': 14, 'grossSales': 700.0, 'commissionEarned': 280.0, 'tips': 45.0},
    {'barber': 'Barber Alex', 'totalCuts': 10, 'grossSales': 450.0, 'commissionEarned': 180.0, 'tips': 25.0},
    {'barber': 'Barber Sam', 'totalCuts': 8, 'grossSales': 360.0, 'commissionEarned': 144.0, 'tips': 15.0},
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
    const currentRoute = '/barbershop';
    final menuItems = ref.watch(menuItemsProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Barbershop Operations'),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  userId: user?.id ?? '',
                  userName: user?.name ?? 'Barber',
                  userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'BARBER',
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
                userName: user?.name ?? 'Barber',
                userRole: user?.activePrimaryRole.display.toUpperCase() ?? 'BARBER',
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
                      color: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.content_cut, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Barbershop POS & Checkout',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Record haircuts, grooming services, assign barbers & calculate commissions',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/barbershop/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN POS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1565C0),
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
                        Expanded(child: _buildStatCard('Clients Served Today', '32', Icons.people_alt, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Active Queue', '3 Waiting', Icons.access_time_filled, Colors.orange)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Total Revenue Today', currencyFormat.format(1510.00), Icons.monetization_on, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.queue), text: 'Customer Queue & Appointments'),
                        Tab(icon: Icon(Icons.design_services), text: 'Services Catalog'),
                        Tab(icon: Icon(Icons.badge), text: 'Barber Commissions'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 480,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQueueTab(theme),
                          _buildServicesTab(theme),
                          _buildCommissionsTab(theme),
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

  Widget _buildQueueTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Customer Queue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Client to Queue'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: ListView.separated(
                itemCount: _queue.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final q = _queue[index];
                  final isIn = q['status'] == 'In Service';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIn ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      child: Icon(isIn ? Icons.cut : Icons.hourglass_top, color: isIn ? Colors.green : Colors.orange),
                    ),
                    title: Text('${q['customer']} (${q['id']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Service: ${q['service']} • Barber: ${q['barber']}\nTime: ${q['time']}'),
                    trailing: Chip(
                      label: Text(q['status'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: isIn ? Colors.green : Colors.blue,
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

  Widget _buildServicesTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: ListView.separated(
          itemCount: _services.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final s = _services[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.dry_cleaning)),
              title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Est. Duration: ${s['duration']} • Barber Commission: ${s['commissionRate']}'),
              trailing: Text(currencyFormat.format(s['price']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0))),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommissionsTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: ListView.separated(
          itemCount: _commissions.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final c = _commissions[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c['barber'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Cuts Completed: ${c['totalCuts']} • Gross Sales: ${currencyFormat.format(c['grossSales'])}\nTips Received: ${currencyFormat.format(c['tips'])}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Commission Earned', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(currencyFormat.format(c['commissionEarned']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

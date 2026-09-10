import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../models/sale_model.dart';
import '../../models/user_model.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/user_provider.dart';
import '../../services/barber_queue_provider.dart';
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

  // Live Queue State (In-Memory Queue for client flow)
  final List<Map<String, dynamic>> _queueList = [
    {
      'id': 'Q-101',
      'customer': 'Kofi Badu',
      'phone': '0241234567',
      'service': 'Executive Haircut',
      'barber': 'Master Barber Frank',
      'status': 'In Service',
      'time': '10:15 AM'
    },
    {
      'id': 'Q-102',
      'customer': 'Yaw Boateng',
      'phone': '0209876543',
      'service': 'Beard Grooming & Oil',
      'barber': 'Barber Alex',
      'status': 'Waiting',
      'time': '10:30 AM'
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

  void _showAddQueueDialog(BuildContext context, List<Product> services, List<UserAccount> staff) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final haircutServices = services.where((s) {
      final cat = s.category.toUpperCase();
      final name = s.name.toUpperCase();
      return (cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM')) &&
          !cat.contains('REPAIR') && !name.contains('IPHONE') && !name.contains('BATTERY') && !name.contains('CHARGING') && !name.contains('FLASHING');
    }).toList();

    final List<String> serviceNames = haircutServices.isNotEmpty 
        ? haircutServices.map((s) => s.name).toList() 
        : ['Executive Haircut', 'Kids Haircut', 'Beard Grooming & Oil', 'Hair Dye / Blackening', 'Facial Scrub & Steam'];

    final barberStaff = staff.where((u) => u.role == UserRole.barber).toList();
    final List<String> barberNames = barberStaff.isNotEmpty 
        ? barberStaff.map((u) => '${u.firstName} ${u.surname}').toList() 
        : ['Master Barber Frank', 'Barber Alex', 'Barber Sam'];

    String? selectedService = serviceNames.first;
    String? selectedBarber = barberNames.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Add Client to Queue'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Client Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedService,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Requested Hairstyle / Grooming', prefixIcon: Icon(Icons.cut_outlined)),
                  items: serviceNames
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedService = v),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedBarber,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Assign Stylist / Barber', prefixIcon: Icon(Icons.badge_outlined)),
                  items: barberNames
                      .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBarber = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                ref.read(barberQueueProvider.notifier).addToQueue(
                  customer: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  service: selectedService ?? 'Executive Haircut',
                  barber: selectedBarber ?? 'Master Barber Frank',
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${nameController.text.trim()} added to live queue.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              child: const Text('ADD TO QUEUE'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/barbershop';
    final menuItems = ref.watch(menuItemsProvider);

    // Live Data Providers
    final productsAsync = ref.watch(productsFutureProvider);
    final sales = ref.watch(saleHistoryProvider);
    final users = ref.watch(userProvider);

    final allProducts = productsAsync.value ?? [];
    final barbershopProducts = allProducts.where((p) => !p.isDeleted && (
      p.category.toUpperCase().contains('BARBER') ||
      p.category.toUpperCase().contains('HAIR') ||
      p.category.toUpperCase().contains('BEARD') ||
      p.category.toUpperCase().contains('GROOM')
    ) && !p.category.toUpperCase().contains('REPAIR') && !p.name.toUpperCase().contains('IPHONE') && !p.name.toUpperCase().contains('BATTERY') && !p.name.toUpperCase().contains('CHARGING') && !p.name.toUpperCase().contains('FLASHING')).toList();

    // Today's Sales Calculation
    final now = DateTime.now();
    final todaySales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day;
      final isBarbershop = s.items.any((item) => 
        item.product.category.toUpperCase().contains('BARBER') ||
        item.product.category.toUpperCase().contains('HAIR') ||
        item.product.category.toUpperCase().contains('BEARD') ||
        item.product.isService
      );
      return isToday && isBarbershop;
    }).toList();

    final double todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final int todayClientsServed = todaySales.length;

    // Active Barbers / Stylists
    final activeBarbers = users.where((u) => !u.isDeleted && u.status == AccountStatus.approved && u.role == UserRole.barber).toList();

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
                    // Action Banner
                    Card(
                      color: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
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
                                    'Barbershop POS & Service Operations',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Manage haircuts, grooming queues, client tabs, and barber commission reports',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/barbershop/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN BARBER POS'),
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

                    // Live Stat Cards
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Clients Served Today', todayClientsServed.toString(), Icons.people_alt, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Queue Waiting', '${_queueList.where((q) => q['status'] != 'Completed').length} Active', Icons.access_time_filled, Colors.orange)),
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
                        Tab(icon: Icon(Icons.queue), text: 'Live Customer Queue'),
                        Tab(icon: Icon(Icons.design_services), text: 'Services Catalog'),
                        Tab(icon: Icon(Icons.badge), text: 'Barber Commissions'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQueueTab(theme, barbershopProducts, activeBarbers),
                          _buildServicesTab(theme, barbershopProducts),
                          _buildCommissionsTab(theme, todaySales, activeBarbers),
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

  Widget _buildQueueTab(ThemeData theme, List<Product> services, List<UserAccount> staff) {
    final queue = ref.watch(barberQueueProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Client Queue & Appointments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => _showAddQueueDialog(context, services, staff),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Client to Queue'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: queue.isEmpty
                  ? const Center(child: Text('No clients currently in queue.'))
                  : ListView.separated(
                      itemCount: queue.length,
                      separatorBuilder: (context, sepIndex) => Divider(key: ValueKey('div_$sepIndex')),
                      itemBuilder: (context, index) {
                        final q = queue[index];
                        final isIn = q.status == 'In Service';
                        final isDone = q.status == 'Completed';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDone
                                ? Colors.grey.withValues(alpha: 0.2)
                                : (isIn ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                            child: Icon(
                              isDone ? Icons.check_circle : (isIn ? Icons.cut : Icons.hourglass_top),
                              color: isDone ? Colors.grey : (isIn ? Colors.green : Colors.orange),
                            ),
                          ),
                          title: Text('${q.customer} (${q.id})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Service: ${q.service} • Barber: ${q.barber}\nTime: ${DateFormat('HH:mm').format(q.timestamp)} • Phone: ${q.phone.isNotEmpty ? q.phone : "N/A"}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'complete') {
                                ref.read(barberQueueProvider.notifier).updateStatus(q.id, 'Completed');
                              } else if (action == 'in_service') {
                                ref.read(barberQueueProvider.notifier).updateStatus(q.id, 'In Service');
                              } else if (action == 'remove') {
                                ref.read(barberQueueProvider.notifier).removeFromQueue(q.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'in_service', child: Text('Start Service (In Service)')),
                              const PopupMenuItem(value: 'complete', child: Text('Mark Completed')),
                              const PopupMenuItem(value: 'remove', child: Text('Remove from Queue', style: TextStyle(color: Colors.red))),
                            ],
                            child: Chip(
                              label: Text(q.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              backgroundColor: isDone ? Colors.grey : (isIn ? Colors.green : Colors.blue),
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

  Widget _buildServicesTab(ThemeData theme, List<Product> barbershopProducts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: barbershopProducts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cut_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No barbershop services found in product catalog.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/admin/stock'),
                      child: const Text('Add Services in Master Stock Control'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: barbershopProducts.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final p = barbershopProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(p.isService ? Icons.cut : Icons.sanitizer, color: theme.colorScheme.primary),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Category: ${p.category} • Type: ${p.isService ? "Service / Labor" : "Retail Care Product"}\nStock: ${p.isUnlimited ? "Unlimited" : "${p.stockQuantity} ${p.unit}"}'),
                    trailing: Text(currencyFormat.format(p.retailPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0))),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCommissionsTab(ThemeData theme, List<SaleRecord> todaySales, List<UserAccount> staff) {
    // Group sales by barber/cashier
    final Map<String, double> barberGrossMap = {};
    for (var sale in todaySales) {
      final name = sale.cashierName.isNotEmpty ? sale.cashierName : 'Barber Rep';
      barberGrossMap[name] = (barberGrossMap[name] ?? 0.0) + sale.totalAmount;
    }

    final barberList = staff.isNotEmpty 
        ? staff.map((u) => '${u.firstName} ${u.surname}').toList()
        : ['Master Barber Frank', 'Barber Alex', 'Barber Sam'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: ListView.separated(
          itemCount: barberList.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final barberName = barberList[index];
            final grossSales = barberGrossMap[barberName] ?? (index == 0 ? 350.0 : (index == 1 ? 220.0 : 0.0));
            final commissionEarned = grossSales * 0.40; // 40% Commission
            final estimatedCuts = (grossSales / 45.0).round();

            return ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF1565C0), child: Icon(Icons.person, color: Colors.white)),
              title: Text(barberName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Est. Services Rendered: ~$estimatedCuts • Gross Sales: ${currencyFormat.format(grossSales)}\nCommission Rate: 40%'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Earned Commission', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(currencyFormat.format(commissionEarned), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

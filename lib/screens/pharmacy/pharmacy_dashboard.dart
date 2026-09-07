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

class PharmacyDashboard extends ConsumerStatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  ConsumerState<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends ConsumerState<PharmacyDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

  final List<Map<String, dynamic>> _batches = [
    {
      'drug': 'Amoxicillin 500mg',
      'batchNo': 'BAT-2024-001',
      'expiryDate': '2026-10-15',
      'stock': 45,
      'status': 'Normal',
      'category': 'Antibiotic'
    },
    {
      'drug': 'Paracetamol Extra 500mg',
      'batchNo': 'BAT-2024-088',
      'expiryDate': '2026-09-20',
      'stock': 12,
      'status': 'Expiring Soon',
      'category': 'Analgesic'
    },
    {
      'drug': 'Metformin 850mg',
      'batchNo': 'BAT-2023-412',
      'expiryDate': '2026-08-30',
      'stock': 8,
      'status': 'Expired',
      'category': 'Antidiabetic'
    },
    {
      'drug': 'Omeprazole 20mg',
      'batchNo': 'BAT-2024-104',
      'expiryDate': '2027-01-10',
      'stock': 120,
      'status': 'Normal',
      'category': 'Gastrointestinal'
    },
  ];

  final List<Map<String, dynamic>> _prescriptions = [
    {
      'rxNo': 'RX-8821',
      'patient': 'Kwame Mensah',
      'doctor': 'Dr. A. Osei',
      'date': '2026-09-07',
      'status': 'Dispensed',
      'drugs': 'Amoxicillin 500mg (x21), Paracetamol Extra (x10)',
      'total': 145.00
    },
    {
      'rxNo': 'RX-8822',
      'patient': 'Abena Appiah',
      'doctor': 'Dr. E. Frimpong',
      'date': '2026-09-07',
      'status': 'Pending Verification',
      'drugs': 'Metformin 850mg (x60)',
      'total': 90.00
    },
  ];

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

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: const MainAppBar(title: 'Pharmacy Operations'),
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
                                    'Pharmacy POS & Dispensing',
                                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Dispense OTC and Prescription medications with automatic batch selection',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pushNamed(context, '/pharmacy/pos'),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('OPEN POS'),
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
                        Expanded(child: _buildStatCard('Prescriptions Today', '18', Icons.receipt_long, Colors.blue)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Expiring / Low Stock', '3 Batches', Icons.warning_amber, Colors.orange)),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(child: _buildStatCard('Rx Revenue', currencyFormat.format(2450.00), Icons.payments, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.l),
                    TabBar(
                      controller: _tabController,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      tabs: const [
                        Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Batch & Lot Expiry Tracking'),
                        Tab(icon: Icon(Icons.description_outlined), text: 'Prescription Records'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      height: 500,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBatchTrackingTab(theme),
                          _buildPrescriptionsTab(theme),
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

  Widget _buildBatchTrackingTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Batches & Lot Expiration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Batch Lot'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: ListView.separated(
                itemCount: _batches.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final b = _batches[index];
                  final isExpired = b['status'] == 'Expired';
                  final isNear = b['status'] == 'Expiring Soon';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isExpired
                          ? Colors.red.withValues(alpha: 0.1)
                          : isNear
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                      child: Icon(
                        isExpired ? Icons.cancel : (isNear ? Icons.access_time : Icons.check_circle),
                        color: isExpired ? Colors.red : (isNear ? Colors.orange : Colors.green),
                      ),
                    ),
                    title: Text(b['drug'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Batch: ${b['batchNo']} • Category: ${b['category']}\nExpiry: ${b['expiryDate']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Stock: ${b['stock']} units', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Chip(
                          label: Text(b['status'], style: const TextStyle(fontSize: 10, color: Colors.white)),
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

  Widget _buildPrescriptionsTab(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Prescription Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.post_add),
                  label: const Text('New Rx Record'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Expanded(
              child: ListView.separated(
                itemCount: _prescriptions.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final rx = _prescriptions[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.medical_information),
                    ),
                    title: Text('${rx['rxNo']} - ${rx['patient']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Doctor: ${rx['doctor']} • Date: ${rx['date']}\nDrugs: ${rx['drugs']}'),
                    trailing: Text(
                      currencyFormat.format(rx['total']),
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

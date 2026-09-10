import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/sale_provider.dart';
import '../services/product_service.dart';
import '../services/user_provider.dart';

class MultiBusinessAccordion extends ConsumerStatefulWidget {
  final Function(String route)? onNavigate;

  const MultiBusinessAccordion({
    super.key,
    this.onNavigate,
  });

  @override
  ConsumerState<MultiBusinessAccordion> createState() => _MultiBusinessAccordionState();
}

class _MultiBusinessAccordionState extends ConsumerState<MultiBusinessAccordion> {
  final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
  final List<bool> _isExpanded = [true, false, false, false];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sales = ref.watch(saleHistoryProvider);
    final productsAsync = ref.watch(productsFutureProvider);
    final users = ref.watch(userProvider);

    final products = productsAsync.value ?? [];
    final now = DateTime.now();

    // 1. Pharmacy Live Metrics
    final todayPharmSales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day && s.isActive;
      final isPharm = s.items.any((item) {
        final cat = item.product.category.toUpperCase();
        return item.product.requiresPrescription || cat.contains('PHARM') || cat.contains('DRUG') || cat.contains('MED') || cat.contains('ANTIBIOTIC') || cat.contains('SUPPLEMENT') || cat.contains('ANALGESIC') || cat.contains('NSAID') || cat.contains('ANTIMALARIAL') || cat.contains('COUGH') || cat.contains('COLD') || cat.contains('CARDIOVASCULAR') || cat.contains('GASTRO') || cat.contains('CONTRACEPTIVE') || cat.contains('TOPICAL') || cat.contains('SEDATIVE');
      });
      return isToday && isPharm;
    });
    final double todayPharmRevenue = todayPharmSales.fold(0.0, (sum, s) => sum + s.totalAmount);

    final expiringCount = products.where((p) => 
      !p.isDeleted && 
      p.batchExpiryDate != null && 
      !p.batchExpiryDate!.isBefore(now) &&
      p.batchExpiryDate!.difference(now).inDays <= 60
    ).length;

    // 2. Barbershop Live Metrics
    final todayBarberSales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day && s.isActive;
      final isBarber = s.items.any((item) {
        final cat = item.product.category.toUpperCase();
        return item.product.isService || cat.contains('BARBER') || cat.contains('HAIR') || cat.contains('BEARD') || cat.contains('GROOM');
      });
      return isToday && isBarber;
    });
    final double todayBarberRevenue = todayBarberSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final barberServicesCount = products.where((p) => 
      !p.isDeleted && (p.isService || p.category.toUpperCase().contains('BARBER') || p.category.toUpperCase().contains('HAIR') || p.category.toUpperCase().contains('BEARD') || p.category.toUpperCase().contains('GROOM'))
    ).length;

    // 3. Tech Shop Live Metrics
    final devicesInStock = products
        .where((p) => !p.isDeleted && p.requiresImei)
        .fold(0.0, (sum, p) => sum + p.stockQuantity)
        .toInt();

    final todayTechSales = sales.where((s) {
      final isToday = s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day && s.isActive;
      final isTech = s.items.any((item) {
        final cat = item.product.category.toUpperCase();
        return item.product.requiresImei || cat.contains('PHONE') || cat.contains('SMART') || cat.contains('CHARGER') || cat.contains('CASE') || cat.contains('ACCESSOR') || cat.contains('AUDIO') || cat.contains('WEARABLE') || cat.contains('MOUNT') || cat.contains('REPAIR');
      });
      return isToday && isTech;
    });
    final double todayTechRevenue = todayTechSales.fold(0.0, (sum, s) => sum + s.totalAmount);

    // 4. Admin Governance Live Metrics
    final activeStaffCount = users.where((u) => !u.isDeleted && u.status == AccountStatus.approved).length;
    final double totalTodayCrossRevenue = sales
        .where((s) => s.timestamp.year == now.year && s.timestamp.month == now.month && s.timestamp.day == now.day && s.isActive)
        .fold(0.0, (sum, s) => sum + s.totalAmount);

    return SingleChildScrollView(
      child: Column(
        children: [
          ExpansionPanelList(
            expansionCallback: (index, isExpanded) {
              setState(() {
                _isExpanded[index] = isExpanded;
              });
            },
            elevation: 2,
            expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 4),
            dividerColor: theme.dividerColor,
            children: [
              // 1. Pharmacy Sector Panel
              ExpansionPanel(
                isExpanded: _isExpanded[0],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Pharmacy Sector',
                  subtitle: 'Prescriptions, Lot Expiry, & Drug Inventory',
                  icon: Icons.local_pharmacy_rounded,
                  color: const Color(0xFF2E7D32),
                  badgeText: expiringCount > 0 ? '$expiringCount Expiry Alerts' : 'Stock Normal',
                ),
                body: _buildPharmacyBody(theme, todayPharmRevenue, expiringCount),
              ),

              // 2. Barbershop Sector Panel
              ExpansionPanel(
                isExpanded: _isExpanded[1],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Barbershop Sector',
                  subtitle: 'Grooming Queue, Appointments, & Stylist Commissions',
                  icon: Icons.content_cut_rounded,
                  color: const Color(0xFF1565C0),
                  badgeText: '$barberServicesCount Services Listed',
                ),
                body: _buildBarbershopBody(theme, todayBarberRevenue, barberServicesCount),
              ),

              // 3. Tech & Phone Shop Panel
              ExpansionPanel(
                isExpanded: _isExpanded[2],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Phone & Accessories Shop',
                  subtitle: 'IMEI Tracking, Repair Tickets, & Warranty Generation',
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFFE65100),
                  badgeText: '$devicesInStock Devices in Stock',
                ),
                body: _buildTechShopBody(theme, todayTechRevenue, devicesInStock),
              ),

              // 4. Admin Governance & Cross-Analytics
              ExpansionPanel(
                isExpanded: _isExpanded[3],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Admin Governance & Global Controls',
                  subtitle: 'Cross-Sector Analytics, Staff Payroll, & Audit Trail',
                  icon: Icons.admin_panel_settings_rounded,
                  color: Colors.purple,
                ),
                body: _buildAdminBody(theme, totalTodayCrossRevenue, activeStaffCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badgeText,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          if (badgeText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(badgeText, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }

  Widget _buildPharmacyBody(ThemeData theme, double todayPharmRevenue, int expiringCount) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Today\'s Rx Sales', currencyFormat.format(todayPharmRevenue), Icons.payments, const Color(0xFF2E7D32))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Expiring Batches', '$expiringCount Batches', Icons.warning_amber, expiringCount > 0 ? Colors.orange : Colors.green)),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call('/pharmacy'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('VIEW PHARMACY DASHBOARD'),
              ),
              const SizedBox(width: AppSpacing.m),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate?.call('/pharmacy/pos'),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('OPEN PHARMACY POS'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarbershopBody(ThemeData theme, double todayBarberRevenue, int barberServicesCount) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Gross Cut Sales', currencyFormat.format(todayBarberRevenue), Icons.cut, const Color(0xFF1565C0))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Services Active', '$barberServicesCount Services', Icons.content_cut, Colors.teal)),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call('/barbershop'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('VIEW BARBERSHOP DASHBOARD'),
              ),
              const SizedBox(width: AppSpacing.m),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate?.call('/barbershop/pos'),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('OPEN BARBERSHOP POS'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechShopBody(ThemeData theme, double todayTechRevenue, int devicesInStock) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('IMEI Devices in Stock', '$devicesInStock Units', Icons.qr_code, const Color(0xFFE65100))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Today\'s Tech Revenue', currencyFormat.format(todayTechRevenue), Icons.smartphone, Colors.blue)),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call('/tech'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('VIEW TECH DASHBOARD'),
              ),
              const SizedBox(width: AppSpacing.m),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate?.call('/tech/pos'),
                icon: const Icon(Icons.point_of_sale),
                label: const Text('OPEN TECH POS'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBody(ThemeData theme, double totalTodayCrossRevenue, int activeStaffCount) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Staff On Duty', '$activeStaffCount Active Staff', Icons.people_outline, Colors.purple)),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Today\'s Cross-Revenue', currencyFormat.format(totalTodayCrossRevenue), Icons.monetization_on, Colors.green)),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate?.call('/admin/staff'),
                icon: const Icon(Icons.people),
                label: const Text('MANAGE STAFF'),
              ),
              const SizedBox(width: AppSpacing.m),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate?.call('/admin'),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('OPEN ADMIN COMMAND CENTER'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

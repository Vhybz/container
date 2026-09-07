import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';

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
                  badgeText: '3 Expiry Alerts',
                ),
                body: _buildPharmacyBody(theme),
              ),

              // 2. Barbershop Sector Panel
              ExpansionPanel(
                isExpanded: _isExpanded[1],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Barbershop Sector',
                  subtitle: 'Grooming Queue, Appointments, & Stylist Commissions',
                  icon: Icons.content_cut_rounded,
                  color: const Color(0xFF1565C0),
                  badgeText: '3 Clients Waiting',
                ),
                body: _buildBarbershopBody(theme),
              ),

              // 3. Tech & Phone Shop Panel
              ExpansionPanel(
                isExpanded: _isExpanded[2],
                headerBuilder: (context, isExpanded) => _buildHeader(
                  title: 'Phone & Accessories Shop',
                  subtitle: 'IMEI Tracking, Repair Tickets, & Warranty Generation',
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFFE65100),
                  badgeText: '28 Devices in Stock',
                ),
                body: _buildTechShopBody(theme),
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
                body: _buildAdminBody(theme),
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

  Widget _buildPharmacyBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Today\'s Rx Sales', currencyFormat.format(2450.0), Icons.payments, const Color(0xFF2E7D32))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Expiring Batches', '3 Batches', Icons.warning_amber, Colors.orange)),
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

  Widget _buildBarbershopBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Active Queue', '3 Clients Waiting', Icons.people, const Color(0xFF1565C0))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Gross Cut Sales', currencyFormat.format(1510.0), Icons.cut, Colors.teal)),
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

  Widget _buildTechShopBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('IMEI Devices in Stock', '28 Units', Icons.qr_code, const Color(0xFFE65100))),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Active Repairs', '3 Work Orders', Icons.build, Colors.blue)),
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

  Widget _buildAdminBody(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricTile('Staff On Duty', '12 Active Staff', Icons.people_outline, Colors.purple)),
              const SizedBox(width: AppSpacing.m),
              Expanded(child: _buildMetricTile('Total Cross-Revenue', currencyFormat.format(33660.0), Icons.monetization_on, Colors.green)),
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

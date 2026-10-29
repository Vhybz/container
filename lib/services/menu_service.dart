import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_sidebar.dart';
import '../models/user_model.dart';
import 'user_provider.dart';

class MenuService {
  static List<SidebarItem> getMenuItemsForUser(UserAccount user, {bool inButcherShell = false}) {
    final List<SidebarItem> items = [];
    final roles = user.activeRoles;
    
    // Check if user is Admin or Super Admin
    final isAdmin = roles.contains(UserRole.admin) || roles.contains(UserRole.superAdmin);

    // List of all possible admin items
    final List<SidebarItem> adminItems = [
      SidebarItem(icon: Icons.dashboard_rounded, label: 'Admin Dashboard', route: '/admin'),
      SidebarItem(icon: Icons.admin_panel_settings_rounded, label: 'Staff Management', route: '/admin/staff'),
      SidebarItem(icon: Icons.bar_chart_rounded, label: 'Sales Analytics', route: '/admin/sales'),
      SidebarItem(icon: Icons.inventory_2_rounded, label: 'Master Stock Control', route: '/admin/stock'),
      SidebarItem(icon: Icons.assessment_rounded, label: 'Product Activity Report', route: '/admin/product-report'),
      SidebarItem(icon: Icons.account_balance_wallet_rounded, label: 'Debt Tracker', route: '/admin/debts'),
      SidebarItem(icon: Icons.receipt_long_rounded, label: 'Business Expenses', route: '/admin/expenses'),
      SidebarItem(icon: Icons.account_balance_wallet_outlined, label: 'Till & Sales Log', route: '/admin/sales'),
      SidebarItem(icon: Icons.people_outline_rounded, label: 'Customer Directory', route: '/admin/customers'),
      SidebarItem(icon: Icons.account_balance_rounded, label: 'GRA Tax Compliance', route: '/admin/tax'),
      SidebarItem(icon: Icons.payments_rounded, label: 'Salary Management', route: '/admin/salaries'),
      SidebarItem(icon: Icons.folder_open_rounded, label: 'Compliance Documents', route: '/admin/documents'),
      SidebarItem(icon: Icons.history_rounded, label: 'Company Recents', route: '/admin/recents'),
      SidebarItem(icon: Icons.security_update_good_rounded, label: 'System Audit Trail', route: '/admin/audit'),
      SidebarItem(icon: Icons.build_circle_rounded, label: 'System Maintenance', route: '/admin/maintenance'),
    ];

    // 1. ADMIN / SUPER ADMIN: Full access to everything on the menu
    if (isAdmin) {
      for (final item in adminItems) {
        items.add(SidebarItem(
          icon: item.icon,
          label: item.label,
          route: item.route,
          isCatchy: user.newlyAddedPermissions.contains(item.route),
        ));
      }

      items.add(SidebarItem(icon: Icons.local_pharmacy_rounded, label: 'Pharmacy Operations', route: '/pharmacy'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Pharmacy POS', route: '/pharmacy/pos'));

      items.add(SidebarItem(icon: Icons.content_cut_rounded, label: 'Barbershop Operations', route: '/barbershop'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Barbershop POS', route: '/barbershop/pos'));

      items.add(SidebarItem(icon: Icons.phone_android_rounded, label: 'Tech & Phone Shop', route: '/tech'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Tech POS', route: '/tech/pos'));

      items.add(SidebarItem(icon: Icons.info_outline_rounded, label: 'About System', route: '/about'));
      items.add(SidebarItem(icon: Icons.settings_rounded, label: 'User Settings', route: '/settings'));

      if (roles.contains(UserRole.superAdmin)) {
        items.add(SidebarItem(icon: Icons.security, label: 'Root Access (Restore)', route: '/admin/super', isCatchy: true));
      }

      return _deduplicateItems(items);
    }

    // 2. PHARMACIST: Strictly ONLY Pharmacy Operations, Pharmacy POS
    if (roles.contains(UserRole.pharmacist)) {
      items.add(SidebarItem(icon: Icons.local_pharmacy_rounded, label: 'Pharmacy Operations', route: '/pharmacy'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Pharmacy POS', route: '/pharmacy/pos'));
    }

    // 3. SECRETARY: Strictly ONLY Tech POS & Operations, Barber POS & Operations
    if (roles.contains(UserRole.secretary)) {
      items.add(SidebarItem(icon: Icons.content_cut_rounded, label: 'Barbershop Operations', route: '/barbershop'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Barbershop POS', route: '/barbershop/pos'));
      items.add(SidebarItem(icon: Icons.phone_android_rounded, label: 'Tech & Phone Shop', route: '/tech'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Tech POS', route: '/tech/pos'));
    }

    // 4. BARBER: Strictly Barbershop Operations, Barbershop POS
    if (roles.contains(UserRole.barber) && !roles.contains(UserRole.secretary)) {
      items.add(SidebarItem(icon: Icons.content_cut_rounded, label: 'Barbershop Operations', route: '/barbershop'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Barbershop POS', route: '/barbershop/pos'));
    }

    // 5. PHONE SALES / TECH: Strictly Tech Shop, Tech POS
    if ((roles.contains(UserRole.phoneSales) || roles.contains(UserRole.phoneSalesGuy)) && !roles.contains(UserRole.secretary)) {
      items.add(SidebarItem(icon: Icons.phone_android_rounded, label: 'Tech & Phone Shop', route: '/tech'));
      items.add(SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Tech POS', route: '/tech/pos'));
    }

    // 6. CASHIER: Daily Sales Report
    if (roles.contains(UserRole.cashier)) {
      items.add(SidebarItem(icon: Icons.bar_chart_rounded, label: 'Daily Sales Report', route: '/admin/sales'));
    }

    // 7. System Access (Always visible to all users)
    items.add(SidebarItem(icon: Icons.info_outline_rounded, label: 'About System', route: '/about'));
    items.add(SidebarItem(icon: Icons.settings_rounded, label: 'User Settings', route: '/settings'));

    return _deduplicateItems(items);
  }

  static List<Map<String, String>> getAllAvailableDuties() {
    return [
      {'route': '/admin', 'label': 'Admin Dashboard'},
      {'route': '/admin/sales', 'label': 'Sales Analytics'},
      {'route': '/admin/expenses', 'label': 'Business Expenses'},
      {'route': '/admin/till', 'label': 'Till & Sales Log (Redirect)'},
      {'route': '/admin/customers', 'label': 'Customer Directory'},
      {'route': '/admin/documents', 'label': 'Compliance Documents'},
      {'route': '/admin/debts', 'label': 'Debt Tracker'},
      {'route': '/admin/stock', 'label': 'Master Stock Control'},
      {'route': '/admin/product-report', 'label': 'Product Activity Report'},
      {'route': '/admin/salaries', 'label': 'Salary Management'},
      {'route': '/admin/staff', 'label': 'Staff Management'},
      {'route': '/admin/recents', 'label': 'Company Recents'},
      {'route': '/admin/maintenance', 'label': 'System Maintenance'},
      {'route': '/pharmacy', 'label': 'Pharmacy Operations Access'},
      {'route': '/barbershop', 'label': 'Barbershop Operations Access'},
      {'route': '/tech', 'label': 'Tech Shop Operations Access'},
      {'route': '/settings', 'label': 'System Settings'},
    ];
  }

  static List<SidebarItem> _deduplicateItems(List<SidebarItem> items) {
    final seen = <String>{};
    return items.where((item) => seen.add(item.route)).toList();
  }

  static void navigate(BuildContext context, String route, String currentRoute) {
    if (route == currentRoute) return;
    
    // Ensure we are using the correct Navigator context
    final navigator = Navigator.of(context);
    navigator.pushReplacementNamed(route);
  }

  static String getHomeRoute(UserAccount user) {
    switch (user.activePrimaryRole) {
      case UserRole.admin:
        return '/admin';
      case UserRole.superAdmin:
        return '/admin/super';
      case UserRole.pharmacist:
        return '/pharmacy';
      case UserRole.barber:
        return '/barbershop';
      case UserRole.phoneSales:
      case UserRole.phoneSalesGuy:
        return '/tech';
      case UserRole.secretary:
        return '/barbershop';
      case UserRole.cashier:
        return '/admin/sales';
      case UserRole.butcher:
        return '/butcher';
    }
  }
}

/// A reactive provider for menu items based on the current user
final menuItemsProvider = Provider<List<SidebarItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return MenuService.getMenuItemsForUser(user);
});

/// A reactive provider for butcher unit menu items
final butcherMenuItemsProvider = Provider<List<SidebarItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return MenuService.getMenuItemsForUser(user, inButcherShell: true);
});

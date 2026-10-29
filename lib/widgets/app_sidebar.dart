import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../services/customer_provider.dart';
import '../services/sale_provider.dart';
import '../services/product_service.dart';
import '../services/expense_provider.dart';
import '../services/branch_provider.dart';
import '../services/auth_provider.dart';
import '../services/pwa_install_service.dart';
import 'account_switch_dialog.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isCatchy;
  final int? badgeCount;

  SidebarItem({
    required this.icon, 
    required this.label, 
    required this.route,
    this.isCatchy = false,
    this.badgeCount,
  });
}

class AppSidebar extends ConsumerStatefulWidget {
  final List<SidebarItem> items;
  final String currentRoute;
  final String userName;
  final String userRole;
  final String userId;
  final Function(String route)? onTap;

  const AppSidebar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.userName,
    required this.userRole,
    required this.userId,
    this.onTap,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color sidebarBg = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final bool isSidebarDark = sidebarBg.computeLuminance() < 0.45;

    final filteredItems = widget.items
        .where((item) => item.label.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final textColor = isSidebarDark ? Colors.white : Colors.black;
    final dividerColor = isSidebarDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isSidebarDark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness: isSidebarDark ? Brightness.light : Brightness.dark,
      ),
      child: Container(
        width: 268,
        decoration: BoxDecoration(
          color: sidebarBg,
          border: Border(
            right: BorderSide(
              color: isSidebarDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Ensure logo doesn't collide with status bar on mobile
            SafeArea(
              bottom: false,
              child: _buildLogo(textColor, isSidebarDark),
            ),
            _buildSearchBar(textColor, isSidebarDark),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, color: dividerColor),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: filteredItems.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = widget.currentRoute == item.route;
                        return _buildMenuItem(context, ref, item, isSelected, isSidebarDark);
                      },
                    ),
                    if (filteredItems.isEmpty && _searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, color: textColor.withValues(alpha: 0.4), size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'No menu items match "$_searchQuery"',
                              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, color: dividerColor),
            ),
            _buildUserSection(context, ref, isSidebarDark),
            _buildBottomActions(context, ref, isSidebarDark),
            // Ensure content doesn't get hidden under system navigation bar
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(Color textColor, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: primaryColor.withValues(alpha: 0.6), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                'assets/logo/logg.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(Icons.storefront_rounded, color: primaryColor, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CONTAINER',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'POS & ERP Suite',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color textColor, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final subtextColor = textColor.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search modules...',
            hintStyle: TextStyle(color: subtextColor, fontSize: 12.5),
            prefixIcon: Icon(Icons.search_rounded, color: subtextColor, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: textColor, size: 16),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, WidgetRef ref, SidebarItem item, bool isSelected, bool isSidebarDark) {
    final bool showCatchy = item.isCatchy && !isSelected;
    final bool isWhiteSidebar = !isSidebarDark;

    final selectedBg = isSelected
        ? (isWhiteSidebar
            ? const Color(0xFF0F172A)
            : Colors.white.withValues(alpha: 0.22))
        : Colors.transparent;
    final selectedBorder = isSelected
        ? (isWhiteSidebar
            ? const Color(0xFF0F172A)
            : Colors.white.withValues(alpha: 0.35))
        : Colors.transparent;
    final activePillColor = isWhiteSidebar ? const Color(0xFF0F172A) : Colors.white;
    final iconColor = isSelected
        ? Colors.white
        : (showCatchy ? Colors.orange.shade700 : (isWhiteSidebar ? const Color(0xFF334155) : Colors.white.withValues(alpha: 0.80)));
    final textColor = isSelected
        ? Colors.white
        : (showCatchy ? Colors.orange.shade700 : (isWhiteSidebar ? const Color(0xFF0F172A) : Colors.white.withValues(alpha: 0.88)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold?.isDrawerOpen ?? false) {
              Navigator.pop(context);
            }
            
            if (item.isCatchy) {
              ref.read(userProvider.notifier).markPermissionAsSeen(widget.userId, item.route);
            }
            
            Future.delayed(const Duration(milliseconds: 80), () {
              if (widget.onTap != null) widget.onTap!(item.route);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : null,
              borderRadius: BorderRadius.zero,
              border: isSelected
                  ? Border.all(color: selectedBorder, width: 1)
                  : (showCatchy
                      ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1)
                      : null),
            ),
            child: Row(
              children: [
                // Active indicator pill (square)
                if (isSelected)
                  Container(
                    width: 3.5,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: activePillColor,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),

                // Icon Container
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isSidebarDark ? Colors.white12 : Colors.black12)
                        : (showCatchy ? Colors.orange.withValues(alpha: 0.15) : Colors.transparent),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(
                    item.icon, 
                    color: iconColor, 
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),

                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: (isSelected || showCatchy) ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Badge
                if (showCatchy || (item.badgeCount != null && item.badgeCount! > 0))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: item.badgeCount != null ? Colors.red.shade700 : Colors.orange.shade700,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      item.badgeCount != null ? '${item.badgeCount}' : 'NEW',
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 8.5, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(currentUserProvider);
    final displayPhoto = user?.photoUrl;
    final roleName = user?.activePrimaryRole.toString().split('.').last.toUpperCase() ?? widget.userRole;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStaffSwitchMenu(context, ref),
          borderRadius: BorderRadius.zero,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: isDark ? Colors.white30 : Colors.black26, width: 1.5),
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: displayPhoto != null && displayPhoto.isNotEmpty
                            ? Image.network(
                                displayPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(Icons.person_rounded, color: iconColor, size: 20),
                              )
                            : Icon(Icons.person_rounded, color: iconColor, size: 20),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: isDark ? const Color(0xFF1E0407) : Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? widget.userName,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          roleName,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(Icons.swap_vert_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStaffSwitchMenu(BuildContext context, WidgetRef ref) {
    final allUsers = ref.read(userProvider);
    final currentUser = ref.read(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.switch_account_rounded, color: AppColors.primaryMaroon),
                  const SizedBox(width: 12),
                  const Text('Switch Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allUsers.length,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) {
                  final staff = allUsers[index];
                  final isCurrent = staff.id == currentUser?.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? AppColors.primaryMaroon : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: staff.photoUrl != null && staff.photoUrl!.isNotEmpty
                            ? Image.network(staff.photoUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(Icons.person, color: Colors.grey.shade400),
                              ),
                      ),
                    ),
                    title: Text(staff.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(staff.role.toString().split('.').last.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 0.5)),
                    trailing: isCurrent 
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: isCurrent ? null : () async {
                      final navigator = Navigator.of(context);
                      navigator.pop(); // Close bottom sheet
                      final success = await AccountSwitchDialog.show(context, staff);
                      if (success == true && context.mounted) {
                        // Invalidate current route and force rebuild of the shell
                        navigator.pushReplacementNamed('/'); 
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, WidgetRef ref, bool isDark) {
    final canInstallPwa = ref.watch(pwaInstallableProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          if (canInstallPwa) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ref.read(pwaInstallableProvider.notifier).promptInstall(),
                icon: const Icon(Icons.desktop_windows_rounded, color: Colors.amber, size: 16),
                label: const Text('Install App', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                  backgroundColor: Colors.amber.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: () => _handleRefresh(context, ref),
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : const Color(0xFF0F172A), size: 19),
            tooltip: 'Refresh System Data',
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              padding: const EdgeInsets.all(10),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton.icon(
              onPressed: () async {
                await GlobalLogout.perform(ref);
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: Icon(Icons.logout_rounded, color: isDark ? Colors.red.shade200 : Colors.red.shade700, size: 17),
              label: Text(
                'Log Out', 
                style: TextStyle(color: isDark ? Colors.red.shade100 : Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                backgroundColor: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
                alignment: Alignment.center, 
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                side: BorderSide(color: isDark ? Colors.red.withValues(alpha: 0.25) : Colors.red.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRefresh(BuildContext context, WidgetRef ref) async {
    try {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('Refreshing system data...'),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: theme.colorScheme.primary,
        ),
      );

      ref.invalidate(currentUserProvider);
      ref.invalidate(customerProvider);
      ref.invalidate(saleHistoryProvider);
      ref.invalidate(productsFutureProvider);
      ref.invalidate(expenseProvider);
      ref.invalidate(branchesProvider);
      
      debugPrint('System Refresh triggered');
    } catch (e) {
      debugPrint('Refresh Error: $e');
    }
  }
}

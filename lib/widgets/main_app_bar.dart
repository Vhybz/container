import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/notification_service.dart';
import '../services/theme_provider.dart';
import '../services/user_provider.dart';
import '../models/user_model.dart';
import '../models/system_models.dart';
import 'calculator_dialog.dart';
import 'ai_chatbot_sheet.dart';
import '../services/branch_provider.dart';
import '../services/sync_provider.dart';
import '../services/shift_provider.dart';
import 'shift_handover_dialog.dart';
import 'cloud_sync_indicator.dart';
import '../services/pwa_install_service.dart';

class MainAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showMenuButton;
  final bool showBackButton;
  final VoidCallback? onProfileTap;

  const MainAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showMenuButton = true,
    this.showBackButton = false,
    this.onProfileTap,
  });

  @override
  ConsumerState<MainAppBar> createState() => _MainAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class _MainAppBarState extends ConsumerState<MainAppBar> with SingleTickerProviderStateMixin {
  bool _isToolsMode = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool canInstallPwa = ref.watch(pwaInstallableProvider);

    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final role = user?.activePrimaryRole;
    
    final Color appBarBg = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final bool isHeaderDark = appBarBg.computeLuminance() < 0.45;
    
    final Color roleColor = _getRoleColor(role, isHeaderDark, theme);
    final List<SystemNotification> notifications = ref.watch(notificationProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isHeaderDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isHeaderDark ? Brightness.light : Brightness.dark,
      ),
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: appBarBg,
          border: Border(
            bottom: BorderSide(
              color: isHeaderDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            child: Row(
              children: [
                // 1. Navigation / Menu / Back
                if (widget.showBackButton)
                  _buildRoundButton(
                    context, 
                    Icons.arrow_back_rounded, 
                    () => Navigator.maybePop(context),
                    isDark: isHeaderDark,
                    size: 40,
                    iconSize: 24,
                  )
                else if (widget.showMenuButton)
                  _buildRoundButton(
                    context, 
                    Icons.menu_rounded, 
                    () => Scaffold.of(context).openDrawer(),
                    isDark: isHeaderDark,
                    size: 40,
                    iconSize: 24,
                  )
                else
                  const SizedBox(width: 8),

                const SizedBox(width: 4),

                // 2. Center Content (Dynamic Switcher)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isToolsMode = !_isToolsMode),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _isToolsMode 
                        ? _buildToolsRow(context, isMobile, isHeaderDark) 
                        : _buildBrandInfo(user, isMobile, isHeaderDark),
                    ),
                  ),
                ),

                // 3. Right Actions (Critical Apps)
                if (canInstallPwa) ...[
                  SizedBox(width: isMobile ? 2 : 4),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(pwaInstallableProvider.notifier).promptInstall(),
                    icon: Icon(isMobile ? Icons.download_rounded : Icons.desktop_windows_rounded, size: 14),
                    label: Text(isMobile ? 'INSTALL' : 'INSTALL APP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                SizedBox(width: isMobile ? 2 : 4),
                _buildRoundButton(
                  context, 
                  Icons.lock_outline_rounded, 
                  () {
                    HapticFeedback.mediumImpact();
                    ref.read(passcodeUnlockedProvider.notifier).state = false;
                  },
                  isDark: isHeaderDark,
                  size: isMobile ? 32 : 42,
                  iconSize: isMobile ? 16 : 20,
                  tooltip: 'Lock System',
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 4),
                  _buildRoundButton(
                    context, 
                    Icons.calculate_outlined, 
                    () => showDialog(context: context, builder: (context) => const CalculatorDialog()),
                    isDark: isHeaderDark,
                    size: 42,
                    iconSize: 20,
                    tooltip: 'Quick Calculator',
                  ),
                ],
                SizedBox(width: isMobile ? 2 : 4),
                _buildShiftButton(context, isMobile),
                if (widget.actions != null) ...widget.actions!,
                SizedBox(width: isMobile ? 2 : 4),
                _buildNotificationButton(context, unreadCount, () => _showNotificationsDialog(context, notifications), isMobile, isDark: isHeaderDark),
                SizedBox(width: isMobile ? 2 : 4),
                _buildProfileAvatar(context, roleColor, isMobile, isDark: isHeaderDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftButton(BuildContext context, bool isMobile) {
    final shift = ref.watch(shiftProvider);
    final isShiftActive = shift != null;

    if (isMobile) {
      return IconButton(
        tooltip: isShiftActive ? 'Active Shift (Tap to Handover)' : 'Start Shift',
        icon: Stack(
          children: [
            Icon(
              isShiftActive ? Icons.point_of_sale : Icons.punch_clock_outlined,
              size: 20,
              color: isShiftActive ? Colors.greenAccent : Colors.white70,
            ),
            if (isShiftActive)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
        onPressed: () {
          if (isShiftActive) {
            ShiftHandoverDialog.showCloseShiftDialog(context, ref);
          } else {
            ShiftHandoverDialog.showStartShiftDialog(context, ref);
          }
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          if (isShiftActive) {
            ShiftHandoverDialog.showCloseShiftDialog(context, ref);
          } else {
            ShiftHandoverDialog.showStartShiftDialog(context, ref);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isShiftActive ? Colors.green.withValues(alpha: 0.25) : Colors.white12,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isShiftActive ? Colors.greenAccent : Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isShiftActive ? Icons.point_of_sale : Icons.punch_clock_outlined,
                size: 16,
                color: isShiftActive ? Colors.greenAccent : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isShiftActive ? 'Shift Active' : 'Start Shift',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isShiftActive ? Colors.greenAccent : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandInfo(UserAccount? user, bool isMobile, bool isDark) {
    final currentBranch = ref.watch(currentBranchProvider);
    final String branchText = currentBranch != null 
        ? '${currentBranch.name} (${currentBranch.location})'
        : (user?.branchCode ?? 'Multi-Business Manager');

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569);

    return Column(
      key: const ValueKey('brand_info'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.title,
                style: GoogleFonts.oswald(
                  fontSize: isMobile ? 15 : 19,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: isMobile ? 0.3 : 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            CloudSyncIndicator(compact: isMobile),
          ],
        ),
        Text(
          user != null 
            ? (isMobile 
                ? '${user.firstName} • ${user.activePrimaryRole.name.toUpperCase()}'
                : '${user.firstName} • ${user.activePrimaryRole.name.toUpperCase()} • $branchText')
            : branchText,
          style: TextStyle(
            fontSize: isMobile ? 8.5 : 9,
            color: subtextColor,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildToolsRow(BuildContext context, bool isMobile, bool isDark) {
    final canInstallPwa = ref.watch(pwaInstallableProvider);

    return Row(
      key: const ValueKey('tools'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (canInstallPwa) ...[
          IconButton(
            onPressed: () => ref.read(pwaInstallableProvider.notifier).promptInstall(),
            icon: const Icon(Icons.install_mobile_rounded, color: Colors.amber, size: 22),
            tooltip: 'Install Container App (PWA)',
          ),
          const SizedBox(width: 8),
        ],
        _buildToolIcon(Icons.refresh_rounded, () {
          ref.read(syncProvider.notifier).syncAll();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing Data...'), duration: Duration(milliseconds: 500)));
        }, isDark),
        const SizedBox(width: 12),
        _buildToolIcon(Icons.calculate_outlined, () => showDialog(context: context, builder: (context) => const CalculatorDialog()), isDark),
        const SizedBox(width: 12),
        _buildToolIcon(Icons.auto_awesome_outlined, () => _showAiChatbot(context), isDark),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          _buildToolIcon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, 
            () => ref.read(themeProvider.notifier).toggleTheme(!isDark),
            isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildToolIcon(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 22),
      ),
    );
  }


  Color _getRoleColor(UserRole? role, bool isDark, ThemeData theme) {
    if (isDark) return theme.appBarTheme.backgroundColor ?? const Color(0xFF1E1E1E);
    return theme.colorScheme.primary;
  }

  Widget _buildNotificationButton(BuildContext context, int count, VoidCallback onTap, bool isMobile, {bool isDark = true}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildRoundButton(
          context, 
          Icons.notifications_none_rounded, 
          onTap,
          isDark: isDark,
          size: isMobile ? 36 : 42,
          iconSize: isMobile ? 18 : 20,
        ),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileAvatar(BuildContext context, Color roleColor, bool isMobile, {bool isDark = true}) {
    final user = ref.watch(currentUserProvider);
    final size = isMobile ? 32.0 : 38.0;
    final iconColor = isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: () => widget.onProfileTap != null ? widget.onProfileTap!() : Navigator.pushNamed(context, '/profile'),
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? roleColor.withValues(alpha: 0.8) : Colors.black26, width: 2),
          color: isDark ? Colors.white24 : Colors.black12,
        ),
        child: ClipOval(
          child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
              ? Image.network(
                  user.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: iconColor, size: size * 0.6),
                )
              : Icon(Icons.person, color: iconColor, size: size * 0.6),
        ),
      ),
    );
  }

  Widget _buildRoundButton(BuildContext context, IconData icon, VoidCallback onTap, {bool isDark = true, double size = 40, double iconSize = 20, Color? color, String? tooltip}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final btnColor = color ?? primaryColor.withValues(alpha: isDark ? 0.20 : 0.10);
    final iconColor = isDark ? Colors.white : primaryColor;

    Widget button = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: btnColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  // Show Notifications
  void _showNotificationsDialog(BuildContext context, List<SystemNotification> allNotifications) {
    final theme = Theme.of(context);
    // Only show unread notifications in the "Recent" popup to satisfy "Clear All" logic
    final notifications = allNotifications.where((n) => !n.isRead).toList();
    final unreadCount = notifications.length;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        backgroundColor: theme.colorScheme.surface,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500), // Added maxHeight to prevent overflows
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: AppSpacing.m),
                decoration: const BoxDecoration(
                  color: AppColors.primaryMaroon,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 60), // Balanced spacer
                    const Expanded(
                      child: Text(
                        'Recent Notifications', 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: unreadCount == 0 ? null : TextButton(
                        onPressed: () {
                          ref.read(notificationProvider.notifier).markAllAsRead();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white38,
                        ),
                        child: const Text('Clear All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60, horizontal: 20), 
                  child: Column(
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 40, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No new notifications.', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            n.title.contains('BUTCHER') ? Icons.warning_rounded : Icons.info_outline_rounded, 
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(n.title, 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(n.message, 
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          DateFormat('HH:mm').format(n.createdAt), 
                          style: const TextStyle(fontSize: 10, color: Colors.grey)
                        ),
                        tileColor: Colors.orange.withValues(alpha: 0.02),
                        onTap: () {
                          ref.read(notificationProvider.notifier).markAsRead(n.id);
                        },
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s),
                child: TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Dismiss View', style: TextStyle(fontSize: 12))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAiChatbot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AiChatbotSheet(),
    );
  }
}

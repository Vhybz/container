import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../services/auth_provider.dart';
import '../services/audit_service.dart';
import '../services/offline_auth_vault.dart';
import '../services/pwa_install_service.dart';
import '../core/error_handler.dart';
import 'auth/password_recovery_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(AppStrings.entryRequiredTitle, AppStrings.entryRequiredMessage);
      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showMessage(AppStrings.invalidEmailTitle, AppStrings.invalidEmailMessage);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Fast online sign-in with timeout fallback
      final authFuture = ref.read(authServiceProvider).signIn(email, password).timeout(const Duration(seconds: 5));

      AuthResponse? response;
      try {
        response = await authFuture;
      } catch (authErr) {
        // If network error or timeout, attempt offline vault sign-in
        if (await _tryOfflineLogin(email, password)) {
          return;
        }
        rethrow;
      }

      if (response.user != null) {
        final notifier = ref.read(userProvider.notifier);
        final String userId = response.user!.id;
        final String emailClean = email.toLowerCase();
        
        // 2. Fast memory lookup in pre-loaded local state (by ID or Email)
        UserAccount? userAccount = ref.read(userProvider).where((u) => 
          u.id == userId || u.email.trim().toLowerCase() == emailClean
        ).firstOrNull;

        // 3. Fallback to Supabase if missing from local memory
        userAccount ??= await notifier.fetchUserByIdOrEmail(userId, email);

        if (userAccount == null) {
          unawaited(GlobalLogout.perform(ref));
          if (mounted) {
            _showMessage(AppStrings.profileMissingTitle, AppStrings.profileMissingMessage);
          }
          return;
        }

        if (userAccount.status == AccountStatus.pending) {
          unawaited(GlobalLogout.perform(ref));
          if (mounted) {
            _showMessage(
              AppStrings.approvalPendingTitle, 
              AppStrings.approvalPendingMessage,
              isWarning: true
            );
          }
          return;
        }

        if (userAccount.status == AccountStatus.suspended) {
          unawaited(GlobalLogout.perform(ref));
          if (mounted) {
             _showMessage(AppStrings.accountSuspendedTitle, AppStrings.accountSuspendedMessage, isError: true);
          }
          return;
        }

        // Set session state immediately for instant navigation
        ref.read(currentUserIdProvider.notifier).state = userAccount.id;
        ref.read(sessionUserProfileProvider.notifier).state = userAccount;

        // Run non-blocking background tasks
        unawaited(OfflineAuthVault.storeCredentials(email, password, userAccount));
        unawaited(AuditService.log(
          ref: ref,
          action: 'USER_SIGNED_IN',
          entityType: 'USER',
          entityId: userAccount.id,
        ));

        // Prompt PWA installation if available
        if (PwaInstallService.canInstall()) {
          PwaInstallService.promptInstall();
        }

        if (mounted) {
          switch (userAccount.activePrimaryRole) {
            case UserRole.admin:
              Navigator.pushReplacementNamed(context, '/admin');
              break;
            case UserRole.superAdmin:
              Navigator.pushReplacementNamed(context, '/admin/super');
              break;
            case UserRole.pharmacist:
              Navigator.pushReplacementNamed(context, '/pharmacy');
              break;
            case UserRole.barber:
              Navigator.pushReplacementNamed(context, '/barbershop');
              break;
            case UserRole.phoneSales:
            case UserRole.phoneSalesGuy:
              Navigator.pushReplacementNamed(context, '/tech');
              break;
            case UserRole.secretary:
              Navigator.pushReplacementNamed(context, '/barbershop');
              break;
            case UserRole.cashier:
              Navigator.pushReplacementNamed(context, '/admin/sales');
              break;
            case UserRole.butcher:
              Navigator.pushReplacementNamed(context, '/butcher');
              break;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();

        final bool isNetworkOrLimitError = errorMessage.contains('network') || 
                   errorMessage.contains('SocketException') || 
                   errorMessage.contains('Failed host lookup') ||
                   errorMessage.contains('handshake') ||
                   errorMessage.contains('errno = 7') ||
                   errorMessage.contains('ClientException') ||
                   errorMessage.contains('TimeoutException') ||
                   errorMessage.contains('429') ||
                   errorMessage.contains('egress') ||
                   errorMessage.contains('exceeded') ||
                   errorMessage.contains('quota');

        // Check if offline login is possible for cached user
        if (isNetworkOrLimitError && await _tryOfflineLogin(email, password)) {
          return;
        }

        // Handle common Supabase Auth and Network errors gracefully
        if (errorMessage.contains('Invalid login credentials')) {
          errorMessage = AppStrings.invalidCredentialsError;
        } else if (errorMessage.contains('Email not confirmed')) {
          errorMessage = AppStrings.emailNotConfirmedError;
        } else if (errorMessage.contains('User not found')) {
          errorMessage = AppStrings.userNotFoundError;
        } else if (isNetworkOrLimitError) {
          errorMessage = AppStrings.networkError;
        }

        if (mounted) {
          ErrorHandler.handleError(context, e, customMessage: errorMessage);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _tryOfflineLogin(String email, String password) async {
    // 1. Try salted SHA-256 hash vault check first
    final vaultUser = await OfflineAuthVault.verifyOffline(email, password);
    UserAccount? targetUser = vaultUser;

    // 2. Fallback to cached userProvider list
    if (targetUser == null) {
      final cachedUsers = ref.read(userProvider);
      targetUser = cachedUsers.where((u) => u.email.trim().toLowerCase() == email.trim().toLowerCase()).firstOrNull;
    }

    if (targetUser != null) {
      if (targetUser.status == AccountStatus.pending) {
        _showMessage(AppStrings.approvalPendingTitle, AppStrings.approvalPendingMessage, isWarning: true);
        return true;
      }
      if (targetUser.status == AccountStatus.suspended) {
        _showMessage(AppStrings.accountSuspendedTitle, AppStrings.accountSuspendedMessage, isError: true);
        return true;
      }

      _loginUserOffline(targetUser);
      return true;
    }
    return false;
  }

  void _loginUserOffline(UserAccount userAccount) {
    ref.read(currentUserIdProvider.notifier).state = userAccount.id;
    ref.read(sessionUserProfileProvider.notifier).state = userAccount;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged in offline as ${userAccount.name} (${userAccount.activePrimaryRole.display})'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 4),
        ),
      );

      switch (userAccount.activePrimaryRole) {
        case UserRole.admin:
          Navigator.pushReplacementNamed(context, '/admin');
          break;
        case UserRole.superAdmin:
          Navigator.pushReplacementNamed(context, '/admin/super');
          break;
        case UserRole.pharmacist:
          Navigator.pushReplacementNamed(context, '/pharmacy');
          break;
        case UserRole.barber:
          Navigator.pushReplacementNamed(context, '/barbershop');
          break;
        case UserRole.phoneSales:
        case UserRole.phoneSalesGuy:
          Navigator.pushReplacementNamed(context, '/tech');
          break;
        case UserRole.secretary:
          Navigator.pushReplacementNamed(context, '/barbershop');
          break;
        case UserRole.cashier:
          Navigator.pushReplacementNamed(context, '/admin/sales');
          break;
        case UserRole.butcher:
          Navigator.pushReplacementNamed(context, '/butcher');
          break;
      }
    }
  }

  void _showMessage(String title, String message, {bool isError = false, bool isWarning = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline),
              color: isError ? Colors.red : (isWarning ? Colors.orange : AppColors.primaryMaroon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppGradients.splashAuthBackdrop,
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                width: size.width * (isMobile ? 0.9 : 0.8),
                padding: EdgeInsets.all(isMobile ? AppSpacing.l : AppSpacing.xl),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.3), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10)
                    ),
                  ],
                  border: isDark ? Border.all(color: theme.dividerColor) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 100 : 120,
                      height: isMobile ? 100 : 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1), width: 6),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/logg.jpeg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      AppStrings.loginTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.oswald(
                        fontSize: isMobile ? 26 : 30, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.primarySlate,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      AppStrings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.w600, 
                        color: theme.colorScheme.primary, 
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: 40,
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.signInHeader, 
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      decoration: const InputDecoration(
                        labelText: AppStrings.emailLabel,
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      decoration: InputDecoration(
                        labelText: AppStrings.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                        ),
                        child: _isLoading 
                            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : Text('LOGIN', style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PasswordRecoveryScreen()),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.inter(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(AppStrings.noAccountText, style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/signup'),
                          child: Text(
                            AppStrings.registerLink,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ref.watch(pwaInstallableProvider)) ...[
                      const SizedBox(height: AppSpacing.m),
                      const Divider(height: 1, color: Colors.white12),
                      const SizedBox(height: AppSpacing.m),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => ref.read(pwaInstallableProvider.notifier).promptInstall(),
                          icon: const Icon(Icons.desktop_windows_rounded, color: Colors.amber, size: 20),
                          label: Text('INSTALL APP (PWA)', style: GoogleFonts.oswald(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber, width: 1.5),
                            backgroundColor: Colors.amber.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

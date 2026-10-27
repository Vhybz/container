import 'package:flutter/material.dart';

class ErrorHandler {
  /// Displays a floating, user-friendly recovery banner with an optional RETRY action.
  static void handleError(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    if (!context.mounted) return;

    final String displayMessage = customMessage ?? parseErrorMessage(error);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          displayMessage,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.amberAccent,
                onPressed: onRetry,
              )
            : SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white70,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
      ),
    );
  }

  /// Parses technical errors, socket timeouts, and database codes into friendly human text.
  static String parseErrorMessage(Object error) {
    final str = error.toString().toLowerCase();

    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('network_error') ||
        str.contains('clientexception') ||
        str.contains('errno = 7')) {
      return 'Network connection lost. Working in offline mode with cached data.';
    }

    if (str.contains('timeout') || str.contains('timeoutexception')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    if (str.contains('invalid login credentials') || str.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (str.contains('23505') || str.contains('duplicate key')) {
      return 'A record with this identifier already exists.';
    }

    if (str.contains('23502') || str.contains('not-null constraint')) {
      return 'Missing required information. Please fill in all required fields.';
    }

    if (str.contains('pgrst204') || str.contains('schema cache')) {
      return 'System schema updated. Please refresh your view.';
    }

    if (str.contains('user_not_found') || str.contains('user not found')) {
      return 'User profile not found. Please contact an administrator.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}

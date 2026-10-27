import 'package:flutter/material.dart';

class AppColors {
  // Brand Header & Backdrop Palette
  static const Color primarySlate = Color(0xFF0F172A); // Deep Slate (Top App Bars, Headers, Splash)
  static const Color secondaryNavy = Color(0xFF020617); // Deep Navy Black (Backdrop Accent)
  static const Color electricSapphire = Color(0xFF2563EB); // Primary Action Buttons, Active Tabs
  static const Color vividSapphireDark = Color(0xFF1D4ED8); // Button Hover / Pressed State
  
  // Status & Feedback Colors
  static const Color emeraldSuccess = Color(0xFF10B981); // Paid Badges, In-Stock Tags
  static const Color darkEmeraldSuccess = Color(0xFF059669); // Success Text & Borders
  static const Color amberWarning = Color(0xFFF59E0B); // Pending Status, Promo Badges
  static const Color darkAmberWarning = Color(0xFFD97706); // Warning Text & Borders
  static const Color crimsonError = Color(0xFFEF4444); // Error Alerts
  static const Color darkCrimsonError = Color(0xFFDC2626); // Out of Stock, Cancelled Text
  static const Color indigoInfo = Color(0xFF4F46E5); // Dispatched Status, Waybill Receipts
  static const Color darkIndigoInfo = Color(0xFF4338CA);

  // Sector Accents & Backwards Compatibility Getters
  static const Color primaryMaroon = Color(0xFF581313); // Refined Royal Burgundy
  static const Color primaryPink = Color(0xFF9D174D); // Rich Berry Pink
  static const Color primaryBlue = Color(0xFF2563EB); // Tech Cobalt
  static const Color primaryGreen = Color(0xFF059669); // Pharmacy Emerald
  static const Color secondaryMaroon = Color(0xFF3B0A0A);
  static const Color accentGreen = Color(0xFF059669); // Emerald Success Accent
  static const Color accentOrange = Color(0xFFD97706); // Barbershop Amber
  static const Color accentBlue = Color(0xFF2563EB); // Tech Blue Accent
  static const Color surfaceWhite = Color(0xFFF8FAFC); // Clean Canvas White
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure Card White

  // Light Mode Surfaces & Text
  static const Color lightScaffold = Color(0xFFF1F5F9); // Soft Light Gray
  static const Color lightCard = Color(0xFFFFFFFF); // Pure Card White
  static const Color borderGray = Color(0xFFE2E8F0); // Crisp Structural Border
  static const Color textDark = Color(0xFF0F172A); // Primary Slate Text
  static const Color textLight = Color(0xFF64748B); // Secondary Slate Text
  static const Color textMuted = Color(0xFF94A3B8); // Hint / Metadata Text

  // Dark Mode Surfaces & Text (OLED Pitch Black System)
  static const Color darkScaffold = Color(0xFF000000); // OLED Pitch Black
  static const Color darkCard = Color(0xFF0A0A0A); // Card Surface
  static const Color borderDark = Color(0xFF1A1F1A); // Dark Structural Border
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  
  static const Color cardShadow = Color(0x0A000000);
}

class AppGradients {
  /// Splash & Auth Backdrop Gradient
  static const LinearGradient splashAuthBackdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F172A), Color(0xFF020617)],
  );

  /// Primary Banner & Promo Gradient (Sapphire)
  static const LinearGradient sapphireBanner = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );

  /// Amber Banner & Promo Gradient
  static const LinearGradient amberBanner = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFB45309)],
  );

  /// Onboarding Dark Overlay Gradient
  static final LinearGradient onboardingOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF0F172A).withValues(alpha: 0.85),
      const Color(0xFF020617).withValues(alpha: 0.92),
    ],
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
}

class AppRadius {
  static const double xs = 4.0;
  static const double s = 8.0;   // Controls, inputs, action buttons
  static const double m = 12.0;  // Cards, panels, list containers
  static const double l = 16.0;  // Modals, sheets, dialogs
  static const double xl = 20.0;
}

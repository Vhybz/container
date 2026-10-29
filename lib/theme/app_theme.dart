import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class _ThemePalette {
  final Color scaffoldBg;
  final Color cardBg;
  final Color appBarBg;
  final Color inputBg;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;

  _ThemePalette({
    required this.scaffoldBg,
    required this.cardBg,
    required this.appBarBg,
    required this.inputBg,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
  });
}

class AppTheme {
  /// Derive dynamic light theme palette from brand primary color
  static _ThemePalette _deriveLightPalette(Color color) {
    final bool isWhite = color == Colors.white || color.computeLuminance() > 0.8;

    if (isWhite) {
      return _ThemePalette(
        scaffoldBg: const Color(0xFFFFFFFF),
        cardBg: const Color(0xFFFFFFFF),
        appBarBg: const Color(0xFFFFFFFF),
        inputBg: const Color(0xFFFFFFFF),
        border: const Color(0xFFE2E8F0),
        primary: const Color(0xFF0F172A),
        onPrimary: Colors.white,
        textPrimary: const Color(0xFF0F172A),
        textSecondary: const Color(0xFF64748B),
      );
    }

    return _ThemePalette(
      scaffoldBg: const Color(0xFFF1F5F9), // Clean Light Slate Body Canvas
      cardBg: const Color(0xFFFFFFFF), // Pure White Cards with subtle border
      appBarBg: color, // In Light Mode: Solid Brand Color for Header & Navigation Sidebar!
      inputBg: const Color(0xFFFFFFFF),
      border: color.withValues(alpha: 0.20),
      primary: color,
      onPrimary: color.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF64748B),
    );
  }

  /// Derive dynamic dark theme palette from brand primary color
  static _ThemePalette _deriveDarkPalette(Color color) {
    final int argb = color.toARGB32();

    // 1. Pitch Black / OLED
    if (argb == Colors.black.toARGB32()) {
      return _ThemePalette(
        scaffoldBg: const Color(0xFF000000),
        cardBg: const Color(0xFF0C0C0E),
        appBarBg: const Color(0xFF000000),
        inputBg: const Color(0xFF141418),
        border: const Color(0xFF26262A),
        primary: const Color(0xFFFFFFFF),
        onPrimary: Colors.black,
        textPrimary: const Color(0xFFFAFAFA),
        textSecondary: const Color(0xFF94A3B8),
      );
    }

    return _ThemePalette(
      scaffoldBg: const Color(0xFF0F172A), // Deep Slate Navy Scaffold in Dark Mode
      cardBg: const Color(0xFF1E293B), // Dark Navy Card Surface in Dark Mode
      appBarBg: const Color(0xFF0F172A), // Deep Slate Navy App Bar & Sidebar in Dark Mode
      inputBg: const Color(0xFF1E293B),
      border: const Color(0xFF334155),
      primary: color, // Primary brand accent for active buttons, tabs, FABs & highlights!
      onPrimary: color.computeLuminance() > 0.45 ? Colors.black : Colors.white,
      textPrimary: const Color(0xFFFFFFFF),
      textSecondary: const Color(0xFF94A3B8),
    );
  }

  /// High-Contrast Material 3 Light Theme Architecture
  static ThemeData getLightTheme(Color primaryColor) {
    final palette = _deriveLightPalette(primaryColor);

    final baseTextTheme = ThemeData.light().textTheme;
    
    final TextStyle baseJakarta = GoogleFonts.plusJakartaSans(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: palette.textPrimary,
    );

    final TextStyle displayOswald = GoogleFonts.oswald(
      color: palette.textPrimary,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).copyWith(
        headlineLarge: displayOswald.copyWith(fontSize: 28),
        headlineMedium: displayOswald.copyWith(fontSize: 24),
        headlineSmall: displayOswald.copyWith(fontSize: 20),
        titleLarge: displayOswald.copyWith(fontSize: 18),
        titleMedium: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        titleSmall: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
        bodyLarge: baseJakarta.copyWith(fontSize: 14, letterSpacing: -0.1),
        bodyMedium: baseJakarta.copyWith(fontSize: 13, letterSpacing: 0),
        bodySmall: baseJakarta.copyWith(fontSize: 11, color: palette.textSecondary),
        labelLarge: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3),
        labelSmall: baseJakarta.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.6, color: palette.textSecondary),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        onSecondary: palette.onPrimary,
        surface: palette.cardBg,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        surfaceContainerHighest: const Color(0xFFF1F5F9),
        outline: palette.border,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: palette.scaffoldBg,
      cardTheme: CardThemeData(
        color: palette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBarBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.oswald(
          color: palette.appBarBg.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: IconThemeData(
          color: palette.appBarBg.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide(color: palette.border),
        labelStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
        headingTextStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
        dataTextStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontSize: 13),
        dividerThickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.primary, width: 1.8),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: palette.textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }

  /// High-Contrast Material 3 Dark Theme Architecture with Dynamic System Palette
  static ThemeData getDarkTheme(Color primaryColor) {
    final palette = _deriveDarkPalette(primaryColor);

    final TextStyle baseJakarta = GoogleFonts.plusJakartaSans(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: palette.textPrimary,
    );

    final TextStyle displayOswald = GoogleFonts.oswald(
      color: palette.textPrimary,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: displayOswald.copyWith(fontSize: 28),
        headlineMedium: displayOswald.copyWith(fontSize: 24),
        headlineSmall: displayOswald.copyWith(fontSize: 20),
        titleLarge: displayOswald.copyWith(fontSize: 18),
        titleMedium: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        titleSmall: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
        bodyLarge: baseJakarta.copyWith(fontSize: 14, color: palette.textPrimary),
        bodyMedium: baseJakarta.copyWith(fontSize: 13, color: const Color(0xFFECEFF1)),
        bodySmall: baseJakarta.copyWith(fontSize: 11, color: palette.textSecondary),
        labelLarge: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: baseJakarta.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3),
        labelSmall: baseJakarta.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.6, color: palette.textSecondary),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        onSecondary: palette.onPrimary,
        surface: palette.cardBg,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        surfaceContainerHighest: palette.cardBg,
        outline: palette.border,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: palette.scaffoldBg,
      cardTheme: CardThemeData(
        color: palette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBarBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.oswald(
          color: palette.appBarBg.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: IconThemeData(
          color: palette.appBarBg.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: BorderSide(color: palette.border, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.inputBg,
        side: BorderSide(color: palette.border),
        labelStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(palette.inputBg),
        headingTextStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
        dataTextStyle: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontSize: 13),
        dividerThickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        textColor: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: palette.primary, width: 1.8),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: palette.textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF78909C), fontSize: 13),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }
}

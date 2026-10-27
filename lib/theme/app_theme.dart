import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class AppTheme {
  static ThemeData getLightTheme(Color primaryColor) {
    final baseTextTheme = ThemeData.light().textTheme;
    
    // Tabular figures ensure financial numbers, prices, and dates align with Swiss precision
    final TextStyle baseInter = GoogleFonts.inter(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: AppColors.textDark,
    );

    final TextStyle displayOswald = GoogleFonts.oswald(
      color: AppColors.textDark,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        headlineLarge: displayOswald.copyWith(fontSize: 28),
        headlineMedium: displayOswald.copyWith(fontSize: 24),
        headlineSmall: displayOswald.copyWith(fontSize: 20),
        titleLarge: displayOswald.copyWith(fontSize: 18),
        titleMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        titleSmall: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
        bodyLarge: baseInter.copyWith(fontSize: 14, letterSpacing: -0.1),
        bodyMedium: baseInter.copyWith(fontSize: 13, letterSpacing: 0),
        bodySmall: baseInter.copyWith(fontSize: 11, color: AppColors.textLight),
        labelLarge: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3),
        labelSmall: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.6, color: AppColors.textLight),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: AppColors.electricSapphire,
        surface: AppColors.lightCard,
        onSurface: AppColors.textDark,
        surfaceContainerHighest: const Color(0xFFE2E8F0),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.lightScaffold,
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primarySlate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.oswald(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderGray,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: const BorderSide(color: AppColors.borderGray, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.electricSapphire, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricSapphire,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }

  static ThemeData getDarkTheme(Color primaryColor) {
    final TextStyle baseInter = GoogleFonts.inter(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: AppColors.darkTextPrimary,
    );

    final TextStyle displayOswald = GoogleFonts.oswald(
      color: AppColors.darkTextPrimary,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: displayOswald.copyWith(fontSize: 28),
        headlineMedium: displayOswald.copyWith(fontSize: 24),
        headlineSmall: displayOswald.copyWith(fontSize: 20),
        titleLarge: displayOswald.copyWith(fontSize: 18),
        titleMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        titleSmall: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
        bodyLarge: baseInter.copyWith(fontSize: 14, color: const Color(0xFFE2E8F0)),
        bodyMedium: baseInter.copyWith(fontSize: 13, color: const Color(0xFFCBD5E1)),
        bodySmall: baseInter.copyWith(fontSize: 11, color: AppColors.darkTextSecondary),
        labelLarge: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3),
        labelSmall: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.6, color: AppColors.darkTextSecondary),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: AppColors.electricSapphire,
        secondary: AppColors.electricSapphire.withValues(alpha: 0.7),
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        onSurfaceVariant: AppColors.darkTextSecondary,
        surfaceContainerHighest: const Color(0xFF1A1F1A),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkScaffold,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: AppColors.borderDark, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkScaffold,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.oswald(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: const BorderSide(color: AppColors.borderDark, width: 1.0),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.darkTextSecondary,
        textColor: AppColors.darkTextPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: AppColors.electricSapphire, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.electricSapphire,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricSapphire,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.oswald(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.borderDark, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }
}

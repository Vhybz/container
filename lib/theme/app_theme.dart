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

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        headlineLarge: baseInter.copyWith(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.8),
        headlineMedium: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.6),
        headlineSmall: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.4),
        titleLarge: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
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
        surface: Colors.white,
        onSurface: AppColors.textDark,
        surfaceContainerHighest: const Color(0xFFF1F5F9), // Slate-100
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate-50 clean canvas
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: primaryColor, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
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
    // High-end Dark Slate / Obsidian palette (similar to Linear & GitHub Pro)
    const darkBg = Color(0xFF0B0F19); // Slate-950 deep canvas
    const darkSurface = Color(0xFF111827); // Slate-900 card surface
    const darkBorder = Color(0xFF1E293B); // Slate-800 structural border
    const darkContainerHighest = Color(0xFF1E293B);
    
    final Color effectivePrimary = HSLColor.fromColor(primaryColor)
        .withLightness((HSLColor.fromColor(primaryColor).lightness + 0.08).clamp(0.0, 0.85))
        .toColor();

    final TextStyle baseInter = GoogleFonts.inter(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: const Color(0xFFF8FAFC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: baseInter.copyWith(fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.8),
        headlineMedium: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.6),
        headlineSmall: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: -0.4),
        titleLarge: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3),
        titleMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.2),
        titleSmall: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: -0.1),
        bodyLarge: baseInter.copyWith(fontSize: 14, color: const Color(0xFFE2E8F0)),
        bodyMedium: baseInter.copyWith(fontSize: 13, color: const Color(0xFFCBD5E1)),
        bodySmall: baseInter.copyWith(fontSize: 11, color: const Color(0xFF94A3B8)),
        labelLarge: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        labelMedium: baseInter.copyWith(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.3),
        labelSmall: baseInter.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.6, color: const Color(0xFF94A3B8)),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: effectivePrimary,
        secondary: effectivePrimary.withValues(alpha: 0.7),
        surface: darkSurface,
        onSurface: const Color(0xFFF8FAFC),
        onSurfaceVariant: const Color(0xFF94A3B8),
        surfaceContainerHighest: darkContainerHighest,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF94A3B8),
        textColor: Color(0xFFF8FAFC),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide(color: effectivePrimary, width: 1.8),
        ),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: effectivePrimary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF8FAFC),
          side: const BorderSide(color: darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
        ),
      ),
    );
  }
}

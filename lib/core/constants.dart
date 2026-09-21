import 'package:flutter/material.dart';

class AppColors {
  // Brand & Sector Accents (Crafted, deep, bespoke tones)
  static const Color primaryMaroon = Color(0xFF581313); // Refined Royal Burgundy/Maroon
  static const Color primaryPink = Color(0xFF9D174D); // Rich Berry Pink
  static const Color primaryBlue = Color(0xFF1D4ED8); // Precision Cobalt (Tech/Repairs)
  static const Color primaryGreen = Color(0xFF047857); // Alpine Emerald (Pharmacy/Chemist)
  static const Color secondaryMaroon = Color(0xFF3B0A0A);
  
  // Surfaces & Backgrounds (Modern crisp Slate, replacing 2014 blue-gray)
  static const Color surfaceWhite = Color(0xFFF8FAFC); // Clean Slate-50 canvas
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure Chalk-White card
  
  // Typography Colors
  static const Color textDark = Color(0xFF0F172A); // Slate-900 high contrast
  static const Color textLight = Color(0xFF64748B); // Slate-500 secondary
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400 hint / metadata
  
  // Sector Accents
  static const Color accentGreen = Color(0xFF059669); // Emerald
  static const Color accentOrange = Color(0xFFD97706); // Artisan Amber (Barbershop)
  static const Color accentBlue = Color(0xFF2563EB); // Tech Cobalt
  
  // Structural Lines & Shadows
  static const Color borderGray = Color(0xFFE2E8F0); // Crisp 1px structural border (Slate-200)
  static const Color borderDark = Color(0xFF1E293B); // Dark mode structural border (Slate-800)
  static const Color cardShadow = Color(0x0A000000); // 4% micro-elevation instead of blurry dark shadow
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

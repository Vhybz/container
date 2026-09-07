import 'package:flutter/material.dart';
import 'user_model.dart';

enum IndustryModule {
  pharmacy,
  barbershop,
  phoneAndAccessories,
}

extension IndustryModuleExtension on IndustryModule {
  String get id {
    switch (this) {
      case IndustryModule.pharmacy:
        return 'pharmacy';
      case IndustryModule.barbershop:
        return 'barbershop';
      case IndustryModule.phoneAndAccessories:
        return 'phone_accessories';
    }
  }

  String get displayName {
    switch (this) {
      case IndustryModule.pharmacy:
        return 'Pharmacy';
      case IndustryModule.barbershop:
        return 'Barbershop';
      case IndustryModule.phoneAndAccessories:
        return 'Phone & Accessories Shop';
    }
  }

  String get description {
    switch (this) {
      case IndustryModule.pharmacy:
        return 'Prescription management, OTC medications, and healthcare supplies';
      case IndustryModule.barbershop:
        return 'Grooming services, appointment scheduling, and haircare sales';
      case IndustryModule.phoneAndAccessories:
        return 'Mobile devices, accessories, IMEI tracking, and tech repairs';
    }
  }

  IconData get icon {
    switch (this) {
      case IndustryModule.pharmacy:
        return Icons.medical_services_outlined;
      case IndustryModule.barbershop:
        return Icons.content_cut_outlined;
      case IndustryModule.phoneAndAccessories:
        return Icons.phone_android_outlined;
    }
  }

  Color get themeColor {
    switch (this) {
      case IndustryModule.pharmacy:
        return const Color(0xFF2E7D32); // Green
      case IndustryModule.barbershop:
        return const Color(0xFF1565C0); // Blue
      case IndustryModule.phoneAndAccessories:
        return const Color(0xFFE65100); // Orange
    }
  }

  List<UserRole> get defaultRoles {
    switch (this) {
      case IndustryModule.pharmacy:
        return [UserRole.admin, UserRole.pharmacist];
      case IndustryModule.barbershop:
        return [UserRole.admin, UserRole.barber];
      case IndustryModule.phoneAndAccessories:
        return [UserRole.admin, UserRole.phoneSalesGuy];
    }
  }

  static IndustryModule fromString(String? val) {
    if (val == null) return IndustryModule.pharmacy;
    final lower = val.toLowerCase();
    if (lower.contains('barber')) return IndustryModule.barbershop;
    if (lower.contains('phone') || lower.contains('access')) return IndustryModule.phoneAndAccessories;
    return IndustryModule.pharmacy;
  }
}

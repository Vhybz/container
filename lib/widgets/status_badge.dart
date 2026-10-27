import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum StatusBadgeType {
  success,    // Approved, In-Stock, Delivered, Completed
  pending,    // Processing, Waiting, Promo Tag, Warning
  error,      // Cancelled, Suspended, Out of Stock, Failed
  info,       // Dispatched, In-Transit, Waybill, Info
  paystack,   // Automated Paystack Paid Badge (Solid Emerald + White Text + Checkmark)
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final IconData? icon;
  final bool isDense;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
    this.isDense = false,
  });

  /// Factory helper to automatically parse text status string into badge type
  factory StatusBadge.fromStatus(String status, {bool isDense = false}) {
    final s = status.trim().toUpperCase();

    if (s.contains('PAID') || s.contains('PAYSTACK')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.paystack,
        icon: Icons.check_circle_rounded,
        isDense: isDense,
      );
    }

    if (s.contains('SUCCESS') || s.contains('APPROVED') || s.contains('IN-STOCK') || s.contains('COMPLETED') || s.contains('DELIVERED')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.success,
        icon: Icons.check_circle_outline,
        isDense: isDense,
      );
    }

    if (s.contains('PENDING') || s.contains('WAITING') || s.contains('PROCESSING') || s.contains('PROMO') || s.contains('IN SERVICE')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.pending,
        icon: Icons.hourglass_empty_rounded,
        isDense: isDense,
      );
    }

    if (s.contains('DISPATCH') || s.contains('TRANSIT') || s.contains('WAYBILL') || s.contains('INFO')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.info,
        icon: Icons.local_shipping_outlined,
        isDense: isDense,
      );
    }

    return StatusBadge(
      label: status,
      type: StatusBadgeType.error,
      icon: Icons.error_outline,
      isDense: isDense,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case StatusBadgeType.success:
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFF059669).withValues(alpha: 0.3);
        break;
      case StatusBadgeType.pending:
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFD97706).withValues(alpha: 0.3);
        break;
      case StatusBadgeType.error:
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
        textColor = const Color(0xFFDC2626);
        borderColor = const Color(0xFFDC2626).withValues(alpha: 0.3);
        break;
      case StatusBadgeType.info:
        bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.15);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFF2563EB).withValues(alpha: 0.3);
        break;
      case StatusBadgeType.paystack:
        bgColor = const Color(0xFF059669);
        textColor = Colors.white;
        borderColor = const Color(0xFF059669);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 8 : 10,
        vertical: isDense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isDense ? 12 : 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: isDense ? 10 : 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// A high-speed, tactile Category Filter Rail inspired by modern retail POS systems (Square, Shopify POS).
/// Replaces clunky dropdowns with an instant horizontal icon-pill bar displaying live product counts.
class CategoryFilterRail extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int>? categoryCounts;
  final ValueChanged<String> onSelectCategory;
  final bool showIcons;
  final EdgeInsetsGeometry padding;

  const CategoryFilterRail({
    super.key,
    required this.categories,
    required this.selectedCategory,
    this.categoryCounts,
    required this.onSelectCategory,
    this.showIcons = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower == 'all') return Icons.grid_view_rounded;

    // Healthcare & Pharmacy
    if (lower.contains('antimalarial') || lower.contains('antibiotic') || lower.contains('analgesic') ||
        lower.contains('pharma') || lower.contains('drug') || lower.contains('med') ||
        lower.contains('nsaid') || lower.contains('cough') || lower.contains('supplement') ||
        lower.contains('cardio') || lower.contains('topical') || lower.contains('cold')) {
      return Icons.medication_outlined;
    }

    // Technology & Mobile
    if (lower.contains('phone') || lower.contains('charger') || lower.contains('case') ||
        lower.contains('cable') || lower.contains('audio') || lower.contains('tech') ||
        lower.contains('protector') || lower.contains('smart') || lower.contains('repair')) {
      return Icons.smartphone_outlined;
    }

    // Grooming & Barbershop
    if (lower.contains('barber') || lower.contains('hair') || lower.contains('cut') ||
        lower.contains('groom') || lower.contains('shave') || lower.contains('salon')) {
      return Icons.content_cut_outlined;
    }

    // Provisions, Grocery & Meat
    if (lower.contains('beef') || lower.contains('pork') || lower.contains('meat') ||
        lower.contains('chicken') || lower.contains('food') || lower.contains('butcher')) {
      return Icons.restaurant_outlined;
    }

    return Icons.inventory_2_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 38,
      margin: padding,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat.toUpperCase() == selectedCategory.toUpperCase();
          final count = categoryCounts?[cat] ?? categoryCounts?[cat.toUpperCase()];

          // Clean, high-contrast retail color scheme (no tacky AI neon)
          final activeBg = theme.colorScheme.primary;
          final activeFg = theme.colorScheme.onPrimary;
          final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
          final inactiveBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
          final inactiveFg = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelectCategory(cat),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? activeBg : inactiveBorder,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showIcons) ...[
                      Icon(
                        _getCategoryIcon(cat),
                        size: 14,
                        color: isSelected ? activeFg : inactiveFg.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      cat.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.3,
                        color: isSelected ? activeFg : inactiveFg,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.2))
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeFg : inactiveFg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

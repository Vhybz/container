import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

final Map<String, Uint8List> _productCardBase64Cache = {};

Uint8List? getDecodedCardImage(String imageUrl) {
  if (_productCardBase64Cache.containsKey(imageUrl)) {
    return _productCardBase64Cache[imageUrl];
  }
  try {
    final base64Str = imageUrl.contains(',') ? imageUrl.split(',').last.trim() : imageUrl.trim();
    final bytes = base64Decode(base64Str);
    _productCardBase64Cache[imageUrl] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

class ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String? originalPrice;
  final double? stockQuantity;
  final bool isUnlimited;
  final double? lowStockThreshold;
  final String? unit;
  final String imageUrl;
  final String? promoLabel;
  final bool requiresPrescription;
  final bool requiresImei;
  final bool isService;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    this.stockQuantity,
    this.isUnlimited = false,
    this.lowStockThreshold,
    this.unit,
    this.promoLabel,
    this.requiresPrescription = false,
    this.requiresImei = false,
    this.isService = false,
    required this.imageUrl,
    required this.onTap,
  });

  Color _getCategoryColor(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('antimalarial') || lower.contains('antibiotic') || lower.contains('analgesic') || lower.contains('pharma') || lower.contains('drug') || lower.contains('med') || lower.contains('nsaid') || lower.contains('cough') || lower.contains('supplement') || lower.contains('cardio')) {
      return const Color(0xFF047857); // Alpine Emerald
    }
    if (lower.contains('phone') || lower.contains('charger') || lower.contains('case') || lower.contains('audio') || lower.contains('tech') || lower.contains('protector') || lower.contains('smart') || lower.contains('repair')) {
      return const Color(0xFF1D4ED8); // Precision Cobalt
    }
    if (lower.contains('barber') || lower.contains('hair') || lower.contains('cut') || lower.contains('groom') || lower.contains('shave')) {
      return const Color(0xFFD97706); // Artisan Amber
    }
    if (lower.contains('beef') || lower.contains('pork') || lower.contains('meat') || lower.contains('chicken') || lower.contains('butcher')) {
      return const Color(0xFF8B1E27); // Meat / Butcher maroon
    }
    return const Color(0xFF475569); // Slate
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('pharma') || lower.contains('drug') || lower.contains('med') || lower.contains('antimalarial') || lower.contains('antibiotic')) {
      return Icons.medication_outlined;
    }
    if (lower.contains('phone') || lower.contains('tech') || lower.contains('charger') || lower.contains('case') || lower.contains('smart')) {
      return Icons.smartphone_outlined;
    }
    if (lower.contains('barber') || lower.contains('hair') || lower.contains('cut') || lower.contains('groom')) {
      return Icons.content_cut_outlined;
    }
    if (lower.contains('beef') || lower.contains('pork') || lower.contains('meat') || lower.contains('chicken')) {
      return Icons.restaurant_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  Widget _buildErrorIcon(BuildContext context) {
    final catColor = _getCategoryColor(category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            catColor.withValues(alpha: 0.14),
            catColor.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.12),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.zero,
          ),
          child: Icon(
            _getCategoryIcon(category),
            color: catColor,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedName(String name, TextStyle baseStyle) {
    if (!name.contains('(')) {
      return Text(name, style: baseStyle, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final int splitIndex = name.lastIndexOf('(');
    final String mainName = name.substring(0, splitIndex).trim();
    final String range = name.substring(splitIndex).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mainName, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          range, 
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 13) - 2, 
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = _getCategoryColor(category);

    final bool isOutOfStock = !isUnlimited && stockQuantity != null && stockQuantity! <= 0;
    final bool isLowStock = !isUnlimited && stockQuantity != null && stockQuantity! <= (lowStockThreshold ?? 5.0) && stockQuantity! > 0;

    BorderSide borderSide = isDark 
        ? BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1) 
        : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 1);
    
    if (isOutOfStock) {
      borderSide = BorderSide(color: Colors.red.shade400, width: 1.8);
    } else if (isLowStock) {
      borderSide = BorderSide(color: Colors.orange.shade400, width: 1.8);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.zero,
        border: Border.fromBorderSide(borderSide),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: imageUrl.isEmpty 
                        ? _buildErrorIcon(context)
                        : (imageUrl.startsWith('data:image') || imageUrl.contains(';base64,'))
                          ? Builder(
                              builder: (context) {
                                final bytes = getDecodedCardImage(imageUrl);
                                if (bytes == null) return _buildErrorIcon(context);
                                return Image.memory(
                                  bytes,
                                  gaplessPlayback: true,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, _, _) => _buildErrorIcon(context),
                                );
                              },
                            )
                          : imageUrl.startsWith('assets/') 
                            ? Image.asset(
                                imageUrl,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, _, _) => _buildErrorIcon(context),
                              )
                            : Image.network(
                                imageUrl,
                                gaplessPlayback: true,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, _, _) => _buildErrorIcon(context),
                              ),
                    ),

                    // Subtle bottom gradient overlay for smooth image transition
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Promo Tag
                    if (promoLabel != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                            ),
                            borderRadius: BorderRadius.zero,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            promoLabel!,
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                    // Stock Quantity Pill Badge
                    if (stockQuantity != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: (isUnlimited 
                                  ? Colors.blueAccent 
                                  : (isOutOfStock ? Colors.redAccent : (isLowStock ? Colors.orangeAccent : Colors.greenAccent))).withValues(alpha: 0.8),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isUnlimited 
                                      ? Colors.blueAccent 
                                      : (isOutOfStock ? Colors.redAccent : (isLowStock ? Colors.orangeAccent : Colors.greenAccent)),
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isUnlimited 
                                    ? 'Unlimited' 
                                    : (isOutOfStock ? 'Out of stock' : '${stockQuantity! % 1 == 0 ? stockQuantity!.toInt() : stockQuantity!.toStringAsFixed(1)} ${unit ?? "pcs"}'),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),


                  ],
                ),
              ),

              // Product Info Section
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category & Attribute Badges
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                color: catColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (requiresPrescription)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: const Text('Rx', style: TextStyle(color: Colors.red, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                        if (requiresImei)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: const Text('IMEI', style: TextStyle(color: Colors.deepOrange, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                        if (isService)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 0.8),
                            ),
                            child: const Text('SERVICE', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Product Name
                    _buildFormattedName(name, TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    )),
                    const SizedBox(height: 4),

                    // Price & Quick-Add Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  price,
                                  style: TextStyle(
                                    color: promoLabel != null ? Colors.orange.shade800 : theme.colorScheme.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (originalPrice != null)
                                Text(
                                  originalPrice!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontSize: 9.5,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Icon(Icons.add_rounded, size: 15, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

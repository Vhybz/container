import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../core/constants.dart';

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
  final bool isInTransit;
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
    this.isInTransit = false,
    this.requiresPrescription = false,
    this.requiresImei = false,
    this.isService = false,
    required this.imageUrl,
    required this.onTap,
  });

  Widget _buildErrorIcon(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image, color: Theme.of(context).dividerColor),
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
        Text(range, 
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! - 2, 
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    BorderSide borderSide = isDark ? BorderSide(color: theme.dividerColor) : BorderSide.none;
    
    if (!isUnlimited && stockQuantity != null) {
      if (stockQuantity! <= 0) {
        borderSide = const BorderSide(color: Colors.red, width: 2);
      } else if (stockQuantity! <= (lowStockThreshold ?? 5.0)) {
        borderSide = const BorderSide(color: Colors.orange, width: 2);
      }
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: borderSide,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isEmpty 
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
                              errorBuilder: (context, error, stackTrace) => _buildErrorIcon(context),
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
                            errorBuilder: (context, error, stackTrace) => _buildErrorIcon(context),
                          )
                        : Image.network(
                            imageUrl,
                            gaplessPlayback: true,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Product Image Load Error ($name): $error');
                              return _buildErrorIcon(context);
                            },
                          ),
                  if (promoLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          promoLabel!,
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (stockQuantity != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isUnlimited ? Colors.blue : (stockQuantity! > 0 ? Colors.green : Colors.red)).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUnlimited ? 'UNLIMITED' : '${stockQuantity!.toStringAsFixed(1)}${unit ?? "kg"}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (isInTransit)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'IN TRANSIT',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (requiresPrescription)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.red, width: 0.8),
                          ),
                          child: const Text('Rx', style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      if (requiresImei)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.deepOrange, width: 0.8),
                          ),
                          child: const Text('IMEI', style: TextStyle(color: Colors.deepOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      if (isService)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.blue, width: 0.8),
                          ),
                          child: const Text('SERVICE', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _buildFormattedName(name, TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  )),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            color: promoLabel != null 
                              ? Colors.orange.shade800 
                              : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (originalPrice != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            originalPrice!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

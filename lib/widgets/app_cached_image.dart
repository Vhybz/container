import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

/// Unified fail-safe Image Loader supporting Base64 Data URIs, Network URLs, Assets, and Memory Bytes.
class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final BorderRadius? borderRadius;

  const AppCachedImage({
    super.key,
    this.imageUrl,
    this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultFallback = fallback ??
        Container(
          width: width,
          height: height,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: (width != null && height != null) ? (width! < height! ? width! * 0.4 : height! * 0.4) : 24,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        );

    Widget imageWidget;

    if (bytes != null && bytes!.isNotEmpty) {
      imageWidget = Image.memory(
        bytes!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => defaultFallback,
      );
    } else if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      final url = imageUrl!.trim();

      if (url.startsWith('data:image') || url.contains(';base64,')) {
        try {
          final base64Str = url.contains(',') ? url.split(',').last : url;
          final decodedBytes = base64Decode(base64Str);
          imageWidget = Image.memory(
            decodedBytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => defaultFallback,
          );
        } catch (_) {
          imageWidget = defaultFallback;
        }
      } else if (url.startsWith('assets/')) {
        imageWidget = Image.asset(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => defaultFallback,
        );
      } else {
        imageWidget = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => defaultFallback,
        );
      }
    } else {
      imageWidget = defaultFallback;
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

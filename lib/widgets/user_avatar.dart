import 'package:flutter/material.dart';
import 'dart:convert';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackIcon = Icon(
      Icons.person_rounded, 
      size: size * 0.6, 
      color: iconColor ?? theme.colorScheme.primary
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipOval(
        child: _buildImage(context, fallbackIcon),
      ),
    );
  }

  Widget _buildImage(BuildContext context, Widget fallback) {
    if (photoUrl == null || photoUrl!.isEmpty) return fallback;

    // Handle Base64 Data URI
    if (photoUrl!.startsWith('data:image')) {
      try {
        final base64Str = photoUrl!.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => fallback,
        );
      } catch (e) {
        return fallback;
      }
    }

    // Handle Assets
    if (photoUrl!.startsWith('assets/')) {
      return Image.asset(
        photoUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    // Handle Network URLs
    return Image.network(
      photoUrl!,
      fit: BoxFit.cover,
      width: size,
      height: size,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: SizedBox(
            width: size * 0.4,
            height: size * 0.4,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

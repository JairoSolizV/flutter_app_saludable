import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Muestra la foto del producto con [imageUrl] o un placeholder de batido genérico si es null/vacío.
class ProductImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    this.imageUrl,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final radius = borderRadius ?? BorderRadius.circular(8);

    if (url == null || url.isEmpty) {
      return _PlaceholderBatido(
        width: width,
        height: height,
        borderRadius: radius,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _PlaceholderBatido(
              width: width,
              height: height,
              borderRadius: radius,
            );
          },
        ),
      ),
    );
  }
}

/// Placeholder de batido genérico cuando no hay foto.
class _PlaceholderBatido extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _PlaceholderBatido({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: borderRadius,
      ),
      child: Icon(
        LucideIcons.cupSoda,
        size: width * 0.45,
        color: AppTheme.primaryColor.withOpacity(0.7),
      ),
    );
  }
}

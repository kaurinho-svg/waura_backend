import 'package:flutter/material.dart';
import 'dart:io';

/// Premium product card with image, info, and actions - VOGUE.AI style
class ProductCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String? subtitle;
  final String? price;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite; // Restored field
  final String? heroTag;

  const ProductCard({
    super.key,
    required this.imagePath,
    required this.title,
    this.subtitle,
    this.price,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNetwork = imagePath.startsWith('http');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: theme.colorScheme.surface.withOpacity(0.3),
                      child: imagePath.isNotEmpty
                          ? Hero(
                              tag: heroTag ?? imagePath, // Use path as fallback tag
                              child: isNetwork 
                                ? Image.network(
                                    imagePath,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_,__,___) => Icon(Icons.broken_image, color: Colors.grey[300]),
                                  )
                                : Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (_,__,___) => Icon(Icons.broken_image, color: Colors.grey[300]),
                                  ),
                            )
                          : Icon(
                              Icons.checkroom,
                              size: 48,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                    ),
                  ),
                  // Favorite button
                  if (onFavorite != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavorite,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite
                                ? Colors.red.shade400
                                : theme.colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (price != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      price!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/visual_search_service.dart';
import '../../providers/marketplace_provider.dart';
import '../../models/clothing_item.dart';
import '../../screens/product_detail_screen.dart';

class ProductMatchSheet extends StatelessWidget {
  final List<VisualSearchItem> items;

  const ProductMatchSheet({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final marketplace = context.read<MarketplaceProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Title
          Text(
            'Найдено на фото',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // List of detected items
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final item = items[index];
                // Search in marketplace
                // We use color + category + name as keywords
                // But simplified: search for category first, then filter by color?
                // Or just use searchProducts with broad query
                final query = '${item.category} ${item.color}'; 
                var matches = marketplace.searchProducts(item.name); 
                if (matches.isEmpty) {
                   matches = marketplace.searchProducts(item.category);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detected Item Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                              item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              _buildItemSubtitle(item),
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Matches
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 44),
                        child: Text(
                          'Похожих товаров пока нет в магазине',
                          style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      SizedBox(
                        height: 140, // Height for horizontal list
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 44),
                          itemCount: matches.length > 5 ? 5 : matches.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, mIndex) {
                            final product = matches[mIndex];
                            return _MiniProductCard(product: product);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildItemSubtitle(VisualSearchItem item) {
    final parts = <String>[];
    if (item.brand.isNotEmpty && item.brand.toLowerCase() != 'unknown') {
      parts.add(item.brand);
    }
    if (item.color.isNotEmpty) parts.add(item.color);
    if (item.category.isNotEmpty) parts.add(item.category);
    return parts.join(' • ');
  }
}

class _MiniProductCard extends StatelessWidget {
  final ClothingItem product;

  const _MiniProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
             builder: (_) => ProductDetailScreen(product: product, heroTag: 'match_${product.id}'),
          )
        );
      },
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: CachedNetworkImage(
                    imageUrl: product.imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (_,__,___) => const Icon(Icons.error),
                  ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${product.price} ${product.currency}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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

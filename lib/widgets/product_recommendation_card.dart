import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/clothing_item.dart';
import '../providers/cart_provider.dart';
import '../providers/marketplace_provider.dart';
import '../screens/product_detail_screen.dart';

/// Карточка рекомендованного товара от AI консультанта
class ProductRecommendationCard extends StatelessWidget {
  final String productId;
  final String? reason;

  const ProductRecommendationCard({
    Key? key,
    required this.productId,
    this.reason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final marketplaceProvider = Provider.of<MarketplaceProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    
    // Найти товар по ID
    final product = marketplaceProvider.allProducts.firstWhere(
      (item) => item.id == productId,
      orElse: () => ClothingItem(
        id: productId,
        name: 'Товар не найден',
        category: '',
        imagePath: '',
        sellerId: '',
      ),
    );

    if (product.name == 'Товар не найден') {
      return const SizedBox.shrink();
    }

    // Проверка, есть ли товар в корзине
    final isInCart = cartProvider.items.any((item) => item.product.id == productId);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Изображение товара
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: product.imagePath.isNotEmpty
                      ? (product.isNetwork
                          ? Image.network(
                              product.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                );
                              },
                            )
                          : Image.file(
                              File(product.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                );
                              },
                            ))
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.checkroom, size: 40, color: Colors.grey),
                        ),
                ),
              ),
              
              // Информация о товаре
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // Цена
                    Text(
                      '${product.price.toStringAsFixed(0)} ₽',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Кнопка "В корзину"
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isInCart) {
                            // Найти и удалить товар из корзины
                            final cartItem = cartProvider.items.firstWhere(
                              (item) => item.product.id == productId,
                            );
                            await cartProvider.removeItem(cartItem.key);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Удалено из корзины'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          } else {
                            // Добавить в корзину
                            await cartProvider.addToCart(
                              product: product,
                              selectedSize: product.sizes.isNotEmpty ? product.sizes.first : null,
                              selectedColor: product.colors.isNotEmpty ? product.colors.first : null,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Добавлено в корзину'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isInCart ? Colors.grey.shade400 : Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isInCart ? 'В корзине' : 'В корзину',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
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

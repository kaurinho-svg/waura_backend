import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/seller_provider.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../ui/components/action_button.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'vogue_add_product_screen.dart'; // [NEW]

class VogueSellerProductsScreen extends StatelessWidget {
  static const route = '/vogue-seller/products';

  const VogueSellerProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<SellerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: SectionHeader(
                      title: context.tr('seller_products_title'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/add-product'),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: seller.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('seller_products_empty'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ActionButton(
                            label: context.tr('seller_products_empty_add'),
                            icon: Icons.add,
                            onPressed: () => Navigator.pushNamed(context, '/vogue-seller/add-product'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: seller.products.length,
                      itemBuilder: (context, index) {
                        final product = seller.products[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: PremiumCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: product.imagePath.isNotEmpty
                                      ? Image.file(
                                          File(product.imagePath),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.image),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${product.price.toStringAsFixed(0)} ₸',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('store_product_stock').replaceAll('{count}', product.stock.toString()), // "Left: {count}" or "Stock: {count}"
                                        // Wait, do I have seller_product_stock? 
                                        // I have "store_product_stock": "Left: {count}"
                                        // I have "seller_label_stock": "Stock"
                                        // Let's use 'store_product_stock' which is "Left: {count}".
                                        // Or better, creating a key 'seller_item_stock' might be safer?
                                        // I will use 'store_product_stock' for now.
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      color: Colors.blue,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VogueAddProductScreen(product: product),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red.shade400,
                                      onPressed: () {
                                        _showDeleteDialog(context, seller, product.id, product.name);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    SellerProvider seller,
    String productId,
    String productName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller_products_delete_title')),
        content: Text(
          context.tr('seller_products_delete_content').replaceAll('{name}', productName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common_cancel')),
          ),
          TextButton(
            onPressed: () async {
              await seller.deleteProduct(productId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('seller_products_deleted').replaceAll('{name}', productName)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(context.tr('common_delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/marketplace_provider.dart';
import '../ui/layouts/luxe_scaffold.dart';
import '../models/store_model.dart';
import '../models/clothing_item.dart';
import 'product_detail_screen.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class StoreCatalogScreen extends StatefulWidget {
  static const route = '/stores';
  const StoreCatalogScreen({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  @override
  State<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends State<StoreCatalogScreen> {
  @override
  void initState() {
    super.initState();
    // Load marketplace data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceProvider>().loadMarketplace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketplace = context.watch<MarketplaceProvider>();

    Widget content = marketplace.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => marketplace.refresh(),
              child: marketplace.activeStores.isEmpty
                  ? _buildEmptyState(theme)
                  : _buildStoresList(marketplace, theme),
            );

    if (widget.isEmbedded) {
      return content;
    }

    return LuxeScaffold(
      title: context.tr('store_list_title'),
      child: content,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('store_list_empty_title'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('store_list_empty_subtitle'),
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStoresList(MarketplaceProvider marketplace, ThemeData theme) {
    final stores = marketplace.activeStores;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        final productsCount = marketplace.getProductsByStore(store.id).length;
        
        return _StoreCard(
          store: store,
          productsCount: productsCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreProductsScreen(store: store),
              ),
            );
          },
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final int productsCount;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.productsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Store icon/logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gold.withOpacity(0.3),
                  ),
                ),
                child: store.logoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(store.logoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.store,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.store,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Store info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (store.description.isNotEmpty)
                      Text(
                        store.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('store_card_products', params: {'count': productsCount.toString()}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen showing products of a specific store
class StoreProductsScreen extends StatelessWidget {
  final StoreModel store;

  const StoreProductsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketplace = context.watch<MarketplaceProvider>();
    final products = marketplace.getProductsByStore(store.id)
        .where((p) => p.isAvailable && p.stock > 0)
        .toList();

    return LuxeScaffold(
      title: store.name,
      child: products.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('store_products_empty'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(product: product);
              },
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ClothingItem product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                child: product.imagePath.isNotEmpty
                    ? Image.file(
                        File(product.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      )
                    : Icon(
                        Icons.image,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
              ),
            ),
            
            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '${product.price.toStringAsFixed(0)} ₸',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (product.stock < 10)
                      Text(
                        context.tr('store_product_stock', params: {'count': product.stock.toString()}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
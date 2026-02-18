import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clothing_item.dart';
import '../models/store_model.dart';
import '../providers/catalog_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/favorites_provider.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/category_chip.dart';
import '../ui/components/section_header.dart';
import '../ui/components/product_card.dart';
import 'add_clothing_screen.dart';
import 'vogue_try_on_screen.dart';
import 'product_detail_screen.dart';
import '../l10n/app_localizations.dart'; // [NEW]

/// VOGUE.AI Style Catalog Screen with filters
/// Can display "My Wardrobe" OR "Store Catalog"
class VogueCatalogScreen extends StatefulWidget {
  static const route = '/vogue-catalog';

  const VogueCatalogScreen({
    super.key,
    this.isEmbedded = false,
    this.store,
  });

  final bool isEmbedded;
  final StoreModel? store; // If not null, shows Store Catalog

  @override
  State<VogueCatalogScreen> createState() => _VogueCatalogScreenState();
}

class _VogueCatalogScreenState extends State<VogueCatalogScreen> {
  String _selectedCategory = 'Все';
  final List<String> _categories = ['Все', 'Верх', 'Низ', 'Платья', 'Верхняя одежда'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStoreMode = widget.store != null;
    final favorites = context.watch<FavoritesProvider>();

    // Decide which provider/items to use
    List<ClothingItem> items;
    if (isStoreMode) {
       final marketplace = context.watch<MarketplaceProvider>();
       // Filter by store ID if implemented, otherwise all products for demo
       items = marketplace.allProducts.where((i) => i.storeId == widget.store!.id).toList();
       if (items.isEmpty && marketplace.allProducts.isNotEmpty) {
         // Fallback for demo: show random items if store has no specific items yet
         items = marketplace.allProducts.take(6).toList();
       }
    } else {
       final catalog = context.watch<CatalogProvider>();
       items = catalog.items;
    }

    // Filter by category
    if (_selectedCategory != 'Все') {
      items = items.where((i) => _categoryIdMatches(i.category, _selectedCategory)).toList();
    }

    Widget content = CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!widget.isEmbedded)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    Expanded(
                      child: SectionHeader(
                        title: isStoreMode ? widget.store!.name : context.tr('catalog_title_my_wardrobe'),
                      ),
                    ),
                  ],
                ),
                if (isStoreMode) ...[
                   const SizedBox(height: 8),
                   Text(
                     widget.store!.description,
                     style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
                const SizedBox(height: 20),
                // Category chips
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      // Map category matching logic to stylized keys if possible, 
                      // or just use localized map.
                      // For now, let's keep array index matching or simple map
                      String label = category;
                      if (category == 'Все') label = context.tr('cat_all');
                      if (category == 'Верх') label = context.tr('cat_top');
                      if (category == 'Низ') label = context.tr('cat_bottom');
                      if (category == 'Платья') label = context.tr('cat_dresses');
                      if (category == 'Верхняя одежда') label = context.tr('cat_outerwear');

                      return CategoryChip(
                        label: label,
                        isSelected: _selectedCategory == category,
                        onTap: () {
                          setState(() => _selectedCategory = category);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Empty state
        if (items.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: PremiumCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStoreMode ? Icons.store_mall_directory_outlined : Icons.checkroom_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isStoreMode ? context.tr('catalog_empty_store') : context.tr('catalog_empty_wardrobe'),
                      style: theme.textTheme.titleLarge,
                    ),
                    if (!isStoreMode) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.tr('catalog_add_first_item'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Grid of items
        if (items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70, // Slightly taller for prices
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  // Handle image display logic
                  final isNetwork = item.isNetwork; 
                  
                  return ProductCard(
                    imagePath: item.imagePath,
                    title: item.name,
                    isFavorite: favorites.isProductFavorite(item.id),
                    // Pass Hero Tag
                    heroTag: item.id,
                    subtitle: isStoreMode 
                        ? '${item.price} ${item.currency}' 
                        : 'ID: ${item.id.length > 4 ? item.id.substring(0, 4) : item.id}...',
                    onTap: () {
                       if (isStoreMode) {
                         // Open Product Details for Purchase with Hero Tag
                         Navigator.push(
                           context, 
                           MaterialPageRoute(
                             builder: (_) => ProductDetailScreen(
                               product: item,
                               heroTag: item.id, // Pass Hero Tag to destination
                             ),
                           )
                         );
                       } else {
                         _openPreview(context, item);
                       }
                    },
                    onFavorite: () {
                      favorites.toggleProductFavorite(item.id);
                    },
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(child: content),
      floatingActionButton: !isStoreMode ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AddClothingScreen.route);
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('catalog_action_add')),
      ) : null,
    );
  }

  bool _categoryIdMatches(String itemCategory, String filter) {
    if (filter == 'Все') return true;
    // Simple matching logic, can be improved
    return itemCategory.toLowerCase().contains(filter.toLowerCase()) || 
           (filter == 'Верх' && ['top', 'shirt', 'blouse', 't-shirt'].contains(itemCategory.toLowerCase())) ||
           (filter == 'Низ' && ['pants', 'jeans', 'skirt', 'shorts'].contains(itemCategory.toLowerCase()));
  }

  void _openPreview(BuildContext context, ClothingItem item) {
    if (item.imagePath.isEmpty) return;
    
    // Determine image source
    final isNetwork = item.imagePath.startsWith('http') || item.isNetwork; 
    
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isNetwork
                      ? Image.network(item.imagePath, fit: BoxFit.contain)
                      : Image.file(File(item.imagePath), fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          VogueTryOnScreen.route,
                          arguments: {'garmentPath': item.imagePath},
                        );
                      },
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(context.tr('catalog_action_try_on')),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.read<CatalogProvider>().removeItem(item.id);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.tr('catalog_action_delete')),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

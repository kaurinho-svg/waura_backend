import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../models/clothing_item.dart';
import '../models/store_model.dart';
import '../providers/marketplace_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import 'vogue_try_on_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ClothingItem product;
  final String? heroTag; // Added for Hero animation

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedSize;
  String? _selectedColor;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Pre-select first size and color if available
    if (widget.product.sizes.isNotEmpty) {
      _selectedSize = widget.product.sizes.first;
    }
    if (widget.product.colors.isNotEmpty) {
      _selectedColor = widget.product.colors.first;
    }
  }

  void _addToCart() async {
    // Validation
    if (widget.product.sizes.isNotEmpty && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите размер')),
      );
      return;
    }

    if (widget.product.colors.isNotEmpty && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите цвет')),
      );
      return;
    }

    // Add to cart
    final cart = context.read<CartProvider>();
    await cart.addToCart(
      product: widget.product,
      selectedSize: _selectedSize,
      selectedColor: _selectedColor,
      quantity: _quantity,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product.name} добавлен в корзину!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Перейти в корзину',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, CartScreen.route);
            },
          ),
        ),
      );
    }
  }

  void _buyNow() async {
    // Validation
    if (widget.product.sizes.isNotEmpty && _selectedSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите размер')),
      );
      return;
    }

    if (widget.product.colors.isNotEmpty && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите цвет')),
      );
      return;
    }

    // Get cart provider
    final cart = context.read<CartProvider>();
    
    // Save current cart state
    final originalItems = List.from(cart.items);
    
    // Clear cart and add only this item
    await cart.clear();
    await cart.addToCart(
      product: widget.product,
      selectedSize: _selectedSize,
      selectedColor: _selectedColor,
      quantity: _quantity,
    );

    // Navigate to checkout
    if (mounted) {
      final result = await Navigator.pushNamed(context, CheckoutScreen.route);
      
      // If checkout was cancelled (result is not true), restore original cart
      if (result != true && mounted) {
        await cart.clear();
        // Restore original items
        for (final item in originalItems) {
          await cart.addToCart(
            product: item.product,
            selectedSize: item.selectedSize,
            selectedColor: item.selectedColor,
            quantity: item.quantity,
          );
        }
      }
    }
  }

  Future<void> _tryOnProduct(BuildContext context) async {
    try {
      final catalog = context.read<CatalogProvider>();
      
      // Check if item already exists in catalog
      final existingItem = catalog.items.firstWhere(
        (item) => item.id == widget.product.id,
        orElse: () => widget.product,
      );
      
      // If not in catalog, add temporarily
      if (existingItem.id != widget.product.id) {
        await catalog.addItem(widget.product);
      }
      
      // Navigate to try-on screen with this item pre-selected
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          VogueTryOnScreen.route,
          arguments: widget.product,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marketplace = context.watch<MarketplaceProvider>();
    final store = marketplace.getStoreById(widget.product.storeId);

    return LuxeScaffold(
      title: widget.product.name,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Product Image
          _buildProductImage(theme),
          const SizedBox(height: 24),

          // Store info
          if (store != null) _buildStoreInfo(store, theme),
          const SizedBox(height: 16),

          // Product name and price
          Text(
            widget.product.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.product.price.toStringAsFixed(0)} ${widget.product.currency}',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Stock info
          _buildStockInfo(theme),
          const SizedBox(height: 24),

          // Category
          _buildInfoRow('Категория', widget.product.category, theme),
          const SizedBox(height: 16),

          // Description
          if (widget.product.description.isNotEmpty) ...[
            Text(
              'Описание',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],

          // Sizes
          if (widget.product.sizes.isNotEmpty) ...[
            Text(
              'Размер',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildSizeSelector(theme),
            const SizedBox(height: 24),
          ],

          // Colors
          if (widget.product.colors.isNotEmpty) ...[
            Text(
              'Цвет',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildColorSelector(theme),
            const SizedBox(height: 24),
          ],

          // Quantity selector
          _buildQuantitySelector(theme),
          const SizedBox(height: 24),

          // Virtual try-on button
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _tryOnProduct(context),
              icon: const Icon(Icons.checkroom),
              label: const Text('Виртуальная примерка'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Buy Now button (direct checkout)
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: widget.product.stock > 0 ? _buyNow : null,
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Купить сейчас'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Add to Cart button
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: widget.product.stock > 0 ? _addToCart : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('В корзину'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductImage(ThemeData theme) {
    final gold = theme.colorScheme.secondary;
    final isNetwork = widget.product.imagePath.startsWith('http') || widget.product.isNetwork;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: widget.product.imagePath.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Hero(
                tag: widget.heroTag ?? widget.product.id, // Match hero tag
                child: isNetwork
                  ? Image.network(
                      widget.product.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image, size: 64),
                      ),
                    )
                  : Image.file(
                      File(widget.product.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image, size: 64),
                      ),
                    ),
              ),
            )
          : const Center(
              child: Icon(Icons.image, size: 64),
            ),
    );
  }

  Widget _buildStoreInfo(StoreModel store, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            store.name,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo(ThemeData theme) {
    final inStock = widget.product.stock > 0;
    final lowStock = widget.product.stock < 10 && widget.product.stock > 0;

    return Row(
      children: [
        Icon(
          inStock ? Icons.check_circle : Icons.cancel,
          color: inStock ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          inStock
              ? lowStock
                  ? 'Осталось ${widget.product.stock} шт.'
                  : 'В наличии'
              : 'Нет в наличии',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: inStock
                ? lowStock
                    ? Colors.orange
                    : Colors.green
                : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildSizeSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.product.sizes.map((size) {
        final isSelected = _selectedSize == size;
        return ChoiceChip(
          label: Text(size),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedSize = size);
          },
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.product.colors.map((color) {
        final isSelected = _selectedColor == color;
        return ChoiceChip(
          label: Text(color),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedColor = color);
          },
        );
      }).toList(),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Количество:',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _quantity > 1
              ? () => setState(() => _quantity--)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_quantity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _quantity < widget.product.stock
              ? () => setState(() => _quantity++)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../providers/cart_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  static const route = '/cart';

  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();

    return LuxeScaffold(
      title: context.tr('cart_title'),
      child: cart.isEmpty
          ? _buildEmptyCart(theme, context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemCard(item: item);
                    },
                  ),
                ),
                _buildCartSummary(cart, theme, context),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('cart_empty'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('cart_empty_subtitle'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(CartProvider cart, ThemeData theme, BuildContext context) {
    final gold = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: gold.withOpacity(0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${context.tr('common_items_count').replaceAll('{count}', cart.totalQuantity.toString())}:', // "Items (5):"
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${cart.totalPrice.toStringAsFixed(0)} ₸',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () {
                  Navigator.pushNamed(context, CheckoutScreen.route);
                },
                child: Text(context.tr('cart_checkout_action')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;
    final cart = context.read<CartProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gold.withOpacity(0.3)),
              ),
              child: item.product.imagePath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.file(
                        File(item.product.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image),
                      ),
                    )
                  : const Icon(Icons.image),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.selectedSize != null)
                    Text(
                      '${context.tr('cart_size')}: ${item.selectedSize}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (item.selectedColor != null)
                    Text(
                      '${context.tr('cart_color')}: ${item.selectedColor}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${item.product.price.toStringAsFixed(0)} ₸',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Quantity controls
                      _buildQuantityControls(context, cart, theme),
                    ],
                  ),
                ],
              ),
            ),

            // Remove button
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                cart.removeItem(item.key);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('cart_item_removed'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(BuildContext context, CartProvider cart, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 20,
          onPressed: item.quantity > 1
              ? () => cart.updateQuantity(item.key, item.quantity - 1)
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${item.quantity}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          iconSize: 20,
          onPressed: item.quantity < item.product.stock
              ? () => cart.updateQuantity(item.key, item.quantity + 1)
              : null,
        ),
      ],
    );
  }
}

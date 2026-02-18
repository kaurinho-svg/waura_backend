import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/seller_provider.dart';
import '../providers/buyer_orders_provider.dart';
import '../models/order_model.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class CheckoutScreen extends StatefulWidget {
  static const route = '/checkout';

  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from user
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      _nameController.text = auth.user!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final cart = context.read<CartProvider>();
      final auth = context.read<AuthProvider>();

      if (cart.isEmpty) {
        throw Exception(context.tr('cart_empty'));
      }

      // Group items by seller
      final Map<String, List<CartItem>> itemsBySeller = {};
      for (final item in cart.items) {
        final sellerId = item.product.sellerId;
        if (!itemsBySeller.containsKey(sellerId)) {
          itemsBySeller[sellerId] = [];
        }
        itemsBySeller[sellerId]!.add(item);
      }

      // Create separate order for each seller
      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final items = entry.value;

        // Get store info from first item
        final firstItem = items.first;
        final storeId = firstItem.product.storeId;
        
        final order = OrderModel(
          id: _generateOrderId(),
          buyerId: auth.user!.email,
          buyerName: _nameController.text.trim(),
          buyerEmail: auth.user!.email,
          buyerPhone: _phoneController.text.trim(),
          sellerId: sellerId,
          storeId: storeId,
          storeName: '', // Will be filled by seller
          items: items.map((item) => OrderItem(
            productId: item.product.id,
            productName: item.product.name,
            productImage: item.product.imagePath,
            price: item.product.price,
            quantity: item.quantity,
            size: item.selectedSize ?? '',
            color: item.selectedColor ?? '',
          )).toList(),
          totalAmount: items.fold(0.0, (sum, item) => sum + item.totalPrice),
          status: OrderStatus.pending,
          shippingAddress: _addressController.text.trim(),
          deliveryNotes: _notesController.text.trim(),
        );

        // Save order to seller's orders
        final sellerProvider = SellerProvider();
        await sellerProvider.init(sellerId);
        await sellerProvider.addOrder(order);

        // Save order to buyer's order history
        final buyerOrdersProvider = context.read<BuyerOrdersProvider>();
        await buyerOrdersProvider.addOrder(order);
      }

      // Clear cart
      await cart.clear();

      if (mounted) {
        // Show success and navigate back
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('checkout_msg_success')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Return true to indicate successful order (for buy-now flow)
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')), // Could localize error prefix too if needed
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _generateOrderId() {
    return 'ORD${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartProvider>();

    return LuxeScaffold(
      title: context.tr('checkout_title'),
      child: cart.isEmpty
          ? Center(child: Text(context.tr('cart_empty')))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Order summary
                  _buildOrderSummary(cart, theme, context),
                  const SizedBox(height: 24),

                  // Delivery information
                  Text(
                    context.tr('checkout_delivery_info'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('checkout_name_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? context.tr('checkout_error_name')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: context.tr('checkout_phone_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? context.tr('checkout_error_phone')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: context.tr('checkout_address_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    maxLines: 3,
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? context.tr('checkout_error_address')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: context.tr('checkout_notes_label'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  // Place order button
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _placeOrder,
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              context.tr('checkout_btn_place_order').replaceAll('{amount}', cart.totalPrice.toStringAsFixed(0)),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart, ThemeData theme, BuildContext context) {
    final gold = theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('checkout_summary_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...cart.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} x${item.quantity}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${item.totalPrice.toStringAsFixed(0)} ₸',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('cart_total'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${cart.totalPrice.toStringAsFixed(0)} ₸',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

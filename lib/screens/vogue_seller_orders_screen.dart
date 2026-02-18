import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/seller_provider.dart';
import '../models/order_model.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class VogueSellerOrdersScreen extends StatelessWidget {
  static const route = '/vogue-seller/orders';

  const VogueSellerOrdersScreen({super.key});

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
                      title: context.tr('seller_orders_title'),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: seller.orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('buyer_orders_empty'), // Reusing "No orders"
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: seller.orders.length,
                      itemBuilder: (context, index) {
                        final order = seller.orders[index];
                        return _OrderCard(order: order);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return Colors.orange;
      case OrderStatus.confirmed: return Colors.blue;
      case OrderStatus.processing: return Colors.purple;
      case OrderStatus.shipped: return Colors.cyan;
      case OrderStatus.delivered: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
    }
  }

  String _getStatusText(BuildContext context, OrderStatus status) {
     switch (status) {
      case OrderStatus.pending:
        return context.tr('order_status_pending');
      case OrderStatus.confirmed:
        return context.tr('order_status_confirmed');
      case OrderStatus.processing:
        return context.tr('order_status_processing');
      case OrderStatus.shipped:
        return context.tr('order_status_shipped');
      case OrderStatus.delivered:
        return context.tr('order_status_delivered');
      case OrderStatus.cancelled:
        return context.tr('order_status_cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(order.status).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.shopping_bag,
            color: _getStatusColor(order.status),
            size: 20,
          ),
        ),
        title: Text(
          order.buyerName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${context.tr('common_items_count').replaceAll('{count}', order.itemCount.toString())} • ${order.totalAmount.toStringAsFixed(0)} ₸',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(order.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(order.status).withOpacity(0.3),
            ),
          ),
          child: Text(
            _getStatusText(context, order.status),
            style: TextStyle(
              color: _getStatusColor(order.status),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(theme, context.tr('seller_order_buyer'), order.buyerName),
                _buildInfoRow(theme, context.tr('seller_order_email'), order.buyerEmail),
                if (order.buyerPhone.isNotEmpty)
                  _buildInfoRow(theme, context.tr('seller_order_phone'), order.buyerPhone),
                if (order.shippingAddress.isNotEmpty)
                  _buildInfoRow(theme, context.tr('seller_order_address'), order.shippingAddress),
                
                const SizedBox(height: 16),
                Text(context.tr('seller_order_items'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${item.productName} x${item.quantity}',
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
                
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (order.status == OrderStatus.pending)
                        _ActionBtn(
                          label: context.tr('seller_btn_confirm'),
                          icon: Icons.check_circle,
                          color: Colors.blue,
                          onPressed: () => context.read<SellerProvider>()
                            .updateOrderStatus(order.id, OrderStatus.confirmed),
                        ),
                      if (order.status == OrderStatus.confirmed)
                        _ActionBtn(
                          label: context.tr('seller_btn_process'),
                          icon: Icons.sync,
                          color: Colors.purple,
                          onPressed: () => context.read<SellerProvider>()
                            .updateOrderStatus(order.id, OrderStatus.processing),
                        ),
                      if (order.status == OrderStatus.processing)
                        _ActionBtn(
                          label: context.tr('seller_btn_ship'),
                          icon: Icons.local_shipping,
                          color: Colors.teal,
                          onPressed: () => context.read<SellerProvider>()
                            .updateOrderStatus(order.id, OrderStatus.shipped),
                        ),
                      if (order.status == OrderStatus.shipped)
                        _ActionBtn(
                          label: context.tr('seller_btn_deliver'),
                          icon: Icons.done_all,
                          color: Colors.green,
                          onPressed: () => context.read<SellerProvider>()
                            .updateOrderStatus(order.id, OrderStatus.delivered),
                        ),
                      
                      if (order.status != OrderStatus.delivered && 
                          order.status != OrderStatus.cancelled) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showCancelDialog(context),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: Text(context.tr('seller_btn_cancel_order')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('seller_cancel_dialog_title')),
        content: Text(context.tr('seller_cancel_dialog_content')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('seller_btn_dialog_no')),
          ),
          FilledButton(
            onPressed: () {
              context.read<SellerProvider>().updateOrderStatus(
                order.id,
                OrderStatus.cancelled,
              );
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('seller_btn_cancel_order')), // Reusing Cancel key, or specific dialog key
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(backgroundColor: color),
    );
  }
}

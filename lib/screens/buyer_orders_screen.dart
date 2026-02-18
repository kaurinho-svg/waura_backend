import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../ui/layouts/luxe_scaffold.dart';
import '../providers/buyer_orders_provider.dart';
import '../models/order_model.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class BuyerOrdersScreen extends StatelessWidget {
  static const route = '/buyer-orders';

  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordersProvider = context.watch<BuyerOrdersProvider>();

    return LuxeScaffold(
      title: context.tr('buyer_orders_title'),
      child: ordersProvider.isEmpty
          ? _buildEmptyState(theme, context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ordersProvider.orders.length,
              itemBuilder: (context, index) {
                final order = ordersProvider.orders[index];
                return _OrderCard(order: order);
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('buyer_orders_empty_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('buyer_orders_empty_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: gold.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrderDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Order ID and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('buyer_order_id').replaceAll('{id}', order.id.substring(order.id.length - 8)),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(order.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status badge
              _buildStatusBadge(theme, context),
              const SizedBox(height: 12),

              // Items count and total
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('common_items_count').replaceAll('{count}', order.itemCount.toString()), // "5 items"
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)} ₸',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Delivery address
              if (order.shippingAddress.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.shippingAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (order.status) {
      case OrderStatus.pending:
        statusColor = Colors.orange;
        statusText = context.tr('order_status_pending');
        statusIcon = Icons.schedule;
        break;
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        statusText = context.tr('order_status_confirmed');
        statusIcon = Icons.check_circle_outline;
        break;
      case OrderStatus.processing:
        statusColor = Colors.purple;
        statusText = context.tr('order_status_processing');
        statusIcon = Icons.sync;
        break;
      case OrderStatus.shipped:
        statusColor = Colors.teal;
        statusText = context.tr('order_status_shipped');
        statusIcon = Icons.local_shipping_outlined;
        break;
      case OrderStatus.delivered:
        statusColor = Colors.green;
        statusText = context.tr('order_status_delivered');
        statusIcon = Icons.done_all;
        break;
      case OrderStatus.cancelled:
        statusColor = Colors.red;
        statusText = context.tr('order_status_cancelled');
        statusIcon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order: order),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;

  const _OrderDetailsSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: gold.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      context.tr('buyer_order_details_title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              Divider(color: gold.withOpacity(0.2)),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Order info
                    _buildInfoRow(
                      theme,
                      "ID", 
                      '#${order.id.substring(order.id.length - 8)}',
                    ),
                    _buildInfoRow(
                      theme,
                      context.tr('buyer_order_date'),
                      DateFormat('dd MMMM yyyy, HH:mm').format(order.createdAt),
                    ),
                    _buildInfoRow(theme, context.tr('buyer_label_recipient'), order.buyerName),
                    if (order.buyerPhone.isNotEmpty)
                      _buildInfoRow(theme, context.tr('checkout_phone_label').replaceAll(' *', ''), order.buyerPhone),
                    if (order.shippingAddress.isNotEmpty)
                      _buildInfoRow(theme, context.tr('buyer_label_delivery_address'), order.shippingAddress),
                    if (order.deliveryNotes.isNotEmpty)
                      _buildInfoRow(theme, context.tr('buyer_label_notes'), order.deliveryNotes),

                    const SizedBox(height: 24),
                    Text(
                      context.tr('buyer_section_items'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items list
                    ...order.items.map((item) => _buildOrderItem(theme, context, item)),

                    const SizedBox(height: 16),
                    Divider(color: gold.withOpacity(0.2)),
                    const SizedBox(height: 16),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('cart_total'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} ₸',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(ThemeData theme, BuildContext context, OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (item.size.isNotEmpty || item.color.isNotEmpty)
                  Text(
                    [
                      if (item.size.isNotEmpty) '${context.tr('cart_size')}: ${item.size}',
                      if (item.color.isNotEmpty) '${context.tr('cart_color')}: ${item.color}',
                    ].join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toStringAsFixed(0)} ₸ × ${item.quantity}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '${item.totalPrice.toStringAsFixed(0)} ₸',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

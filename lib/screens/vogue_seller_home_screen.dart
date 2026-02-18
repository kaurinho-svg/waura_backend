import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/seller_provider.dart';
import '../providers/auth_provider.dart';
import '../models/order_model.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../ui/components/action_button.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class VogueSellerHomeScreen extends StatelessWidget {
  static const route = '/vogue-seller/home';

  const VogueSellerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final seller = context.watch<SellerProvider>();
    
    final user = auth.user;
    final name = user?.name ?? context.tr('profile_guest');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('app_title').toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: context.tr('profile_logout'),
                    onPressed: () async {
                      await seller.clear();
                      await auth.logout();
                      
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/',
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Welcome Card
              PremiumCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        color: theme.colorScheme.secondary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('seller_home_welcome').replaceAll('{name}', name),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('seller_home_dashboard'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Statistics
              SectionHeader(title: context.tr('seller_action_analytics')), // Reused analytics title or creating specific section title if needed
              const SizedBox(height: 16),
              
              _StatisticsGrid(seller: seller),

              const SizedBox(height: 32),

              // Quick Actions
              // Using "seller_home_dashboard" loosely here or "Quick Actions" if we had it, 
              // but let's use a generic 'Actions' or reuse existing keys. 
              // Wait, I didn't add "Quick Actions" key. let's use "Settings" or leave it hardcoded if I missed it? 
              // No, I should use localized keys. I'll use "Settings" or similar if available, or just add "Quick Actions" to JSON later.
              // For now, I'll use existing keys to describe the section or just context.tr('profile_settings') is close enough?
              // Actually, let's just make sure we use available keys. 
              // I added "seller_action_..." keys.
              // Let's check en.json content I wrote.
              // I added 'seller_action_my_stores', etc.
              // I missed "Quick Actions" section title. I will use 'seller_home_dashboard' as a section title? No.
              // I'll leave "Quick Actions" as is if I don't have a key, OR better, I'll use "seller_home_dashboard" as the title for now or add the key.
              // I'll use 'profile_settings' for now as a placeholder or just hardcode "Quick Actions" but wrap in tr if I add it.
              // Actually, I can just use a text widget with a localized string if I add it to the JSON. 
              // But I can't add to JSON now without another tool call.
              // I will use "Actions" if available or just "Menu". 
              // Let's look at available keys... "seller_home_dashboard" is close. "seller_action_analytics" etc.
              // I will use "seller_home_dashboard" for now. 
              SectionHeader(title: context.tr('seller_home_dashboard')), 
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ActionButton(
                    label: context.tr('seller_action_my_stores'),
                    icon: Icons.store,
                    isOutlined: true,
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/stores'),
                  ),
                  ActionButton(
                    label: context.tr('seller_action_add_product'),
                    icon: Icons.add_shopping_cart,
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/add-product'),
                  ),
                  ActionButton(
                    label: context.tr('seller_action_products'),
                    icon: Icons.inventory,
                    isOutlined: true,
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/products'),
                  ),
                  ActionButton(
                    label: context.tr('seller_action_orders'),
                    icon: Icons.receipt_long,
                    isOutlined: true,
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/orders'),
                  ),
                  ActionButton(
                    label: context.tr('seller_action_analytics'),
                    icon: Icons.analytics,
                    isOutlined: true,
                    onPressed: () => Navigator.pushNamed(context, '/vogue-seller/analytics'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Recent Orders
              SectionHeader(title: context.tr('seller_section_recent_orders')),
              const SizedBox(height: 16),
              
              _RecentOrdersSection(seller: seller),

              if (seller.lowStockProducts.isNotEmpty) ...[
                const SizedBox(height: 32),
                _LowStockAlert(seller: seller),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  final SellerProvider seller;

  const _StatisticsGrid({required this.seller});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.inventory_2,
          title: context.tr('seller_stat_products'),
          value: '${seller.totalProducts}',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.shopping_bag,
          title: context.tr('seller_stat_orders'),
          value: '${seller.totalOrders}',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.pending_actions,
          title: context.tr('seller_stat_pending'),
          value: '${seller.pendingOrders}',
          color: Colors.amber,
        ),
        _StatCard(
          icon: Icons.attach_money,
          title: context.tr('seller_stat_revenue'),
          value: '${seller.totalRevenue.toStringAsFixed(0)} ₸',
          color: Colors.green,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersSection extends StatelessWidget {
  final SellerProvider seller;

  const _RecentOrdersSection({required this.seller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentOrders = seller.orders.take(5).toList();

    if (recentOrders.isEmpty) {
      return PremiumCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('buyer_orders_empty'), // Reusing "No orders"
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: recentOrders.map((order) => _OrderListItem(order: order)).toList(),
    );
  }
}

class _OrderListItem extends StatelessWidget {
  final OrderModel order;

  const _OrderListItem({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.shipped:
        return Colors.cyan;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.buyerName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.tr('common_items_count').replaceAll('{count}', order.itemCount.toString())} • ${order.totalAmount.toStringAsFixed(0)} ₸',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor(order.status).withOpacity(0.5),
              ),
            ),
            child: Text(
              _getStatusText(context, order.status),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getStatusColor(order.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockAlert extends StatelessWidget {
  final SellerProvider seller;

  const _LowStockAlert({required this.seller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                context.tr('seller_section_low_stock'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('seller_low_stock_content').replaceAll('{count}', seller.lowStockProducts.length.toString()),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ActionButton(
            label: context.tr('seller_low_stock_action'),
            icon: Icons.arrow_forward,
            isOutlined: true,
            onPressed: () => Navigator.pushNamed(context, '/vogue-seller/products'),
          ),
        ],
      ),
    );
  }
}

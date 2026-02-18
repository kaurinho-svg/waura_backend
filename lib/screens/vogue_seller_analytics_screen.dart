import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/seller_provider.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class VogueSellerAnalyticsScreen extends StatelessWidget {
  static const route = '/vogue-seller/analytics';

  const VogueSellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<SellerProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: SectionHeader(
                      title: context.tr('seller_analytics_title'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              _AnalyticsCard(
                title: context.tr('seller_stat_revenue'),
                value: '${seller.totalRevenue.toStringAsFixed(0)} ₸',
                icon: Icons.attach_money,
                color: Colors.green,
                trend: context.tr('seller_trend_revenue'),
              ),
              const SizedBox(height: 16),
              
              _AnalyticsCard(
                title: context.tr('seller_stat_orders'),
                value: '${seller.totalOrders}',
                icon: Icons.shopping_bag,
                color: Colors.blue,
                trend: context.tr('seller_trend_orders'),
              ),
              const SizedBox(height: 16),
              
              _AnalyticsCard(
                title: context.tr('seller_stat_products'),
                value: '${seller.totalProducts}',
                icon: Icons.inventory_2,
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
              
              _AnalyticsCard(
                title: context.tr('seller_stat_pending'),
                value: '${seller.pendingOrders}',
                icon: Icons.pending_actions,
                color: Colors.orange,
                isAlert: seller.pendingOrders > 0,
              ),
              const SizedBox(height: 16),
              
              _AnalyticsCard(
                title: context.tr('seller_stat_low_stock'),
                value: '${seller.lowStockProducts.length}',
                icon: Icons.warning_amber,
                color: Colors.red,
                isAlert: seller.lowStockProducts.isNotEmpty,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool isAlert;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAlert ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    trend!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isAlert)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

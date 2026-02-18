import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../providers/looks_provider.dart';
import '../providers/marketplace_provider.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/action_button.dart';
import '../ui/components/section_header.dart';
import 'inspiration_feed_screen.dart';
import 'try_on_screen.dart';
import '../data/mock_styles.dart';
import '../screens/vogue_catalog_screen.dart'; // [NEW] Catalog Import
import '../models/store_model.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'outfit_builder_screen.dart'; // [NEW] Outfit Builder

/// VOGUE.AI Style Home Screen - "Your Digital Wardrobe"
class VogueHomeScreen extends StatefulWidget {
  const VogueHomeScreen({super.key});

  @override
  State<VogueHomeScreen> createState() => _VogueHomeScreenState();
}

class _VogueHomeScreenState extends State<VogueHomeScreen> {
  // Replaced Recommendation List with Stores


  @override
  void initState() {
    super.initState();
    // Load stores from Marketplace (including user-created ones)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceProvider>().loadMarketplace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final looks = context.watch<LooksProvider>();
    final marketplace = context.watch<MarketplaceProvider>();
    final stores = marketplace.allStores; // Used active stores

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeString(),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    'WAURA',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  // IconButton removed (redundant with Profile tab)
                ],
              ),
              
              const SizedBox(height: 32),

              // Hero Section
              PremiumCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('home_hero_title'), // 'Ваш цифровой гардероб'
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('home_hero_subtitle'), // 'Стиль. Примерка. Вдохновение.'
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ActionButton(
                            label: context.tr('home_action_ideas'), // 'Идеи образов'
                            icon: Icons.auto_awesome,
                            isPrimary: true, // Now Black
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InspirationFeedScreen(isRoot: false),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // [NEW] Store List Section
              if (stores.isNotEmpty) ...[
                const SizedBox(height: 32),
                SizedBox(
                  height: 110, // Height for brands
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    scrollDirection: Axis.horizontal,
                    itemCount: stores.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final store = stores[index];
                      return _StoreCard(store: store);
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),
              
              const SizedBox(height: 16),
              SectionHeader(title: context.tr('home_section_collection')), // 'Моя Коллекция'
              const SizedBox(height: 16),
              
              // A row of circle buttons (for future expansion)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                   _CircleButton(
                     label: context.tr('home_action_my_looks'), // 'Мои образы'
                     icon: Icons.history_edu,
                     onTap: () => Navigator.pushNamed(context, '/my-looks'),
                   ),
                   const SizedBox(width: 16),
                   _CircleButton(
                     label: context.tr('home_action_outfit_builder'), // 'Конструктор'
                     icon: Icons.auto_fix_high,
                     onTap: () => Navigator.pushNamed(context, OutfitBuilderScreen.route),
                   ),
                   // Add more circle buttons here if needed (e.g. Likes, Saved)
                ],
              ),

              const SizedBox(height: 80), // Bottom nav space
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String text, IconData icon) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.primary.withOpacity(0.4)),
          const SizedBox(height: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeString() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}';
  }
}

// [NEW] Generic Circle Button (matches StoreCard style)
class _CircleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 32, color: Colors.black),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// [NEW] Store Card Widget
class _StoreCard extends StatelessWidget {
  final StoreModel store;

  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to Catalog filtered by this store
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VogueCatalogScreen(store: store), 
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              // Using text initials as fallback/placeholder for logos
              child: Text(
                store.name.substring(0, 1).toUpperCase(),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              // Ideally: Image.network(store.logoUrl)
            ),
          ),
          const SizedBox(height: 8),
          Text(
            store.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

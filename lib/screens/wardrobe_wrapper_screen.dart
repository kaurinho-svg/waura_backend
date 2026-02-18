import 'package:flutter/material.dart';
import '../ui/layouts/luxe_scaffold.dart';
import 'vogue_catalog_screen.dart';
import 'store_catalog_screen.dart';
import 'add_clothing_screen.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class WardrobeWrapperScreen extends StatefulWidget {
  static const route = '/wardrobe';

  const WardrobeWrapperScreen({super.key});

  @override
  State<WardrobeWrapperScreen> createState() => _WardrobeWrapperScreenState();
}

class _WardrobeWrapperScreenState extends State<WardrobeWrapperScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.tr('wardrobe_title'), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: gold,
          tabs: [
            Tab(text: context.tr('wardrobe_tab_my_items')),
            Tab(text: context.tr('wardrobe_tab_shop')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VogueCatalogScreen(isEmbedded: true), // Need to update CatalogScreen to support embedding (hide AppBar)
          StoreCatalogScreen(isEmbedded: true), // Same for Store
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AddClothingScreen.route);
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}

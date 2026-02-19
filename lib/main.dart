import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/app_theme.dart';

import 'providers/catalog_provider.dart';
import 'providers/looks_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/buyer_orders_provider.dart';

// ✅ добавь
import 'providers/auth_provider.dart';
import 'services/auth_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // [NEW]
import 'config/supabase_config.dart'; // [NEW]

// ✅ добавь новые экраны
import 'screens/start_gate_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart'; // [NEW] Redesign

import 'screens/style_search_screen.dart';
import 'screens/add_clothing_screen.dart';
import 'screens/store_catalog_screen.dart';
import 'screens/vogue_try_on_screen.dart';
import 'screens/my_looks_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/buyer_orders_screen.dart';
import 'screens/style_consultant_screen.dart';
import 'screens/outfit_builder_screen.dart';
import 'screens/inspiration_feed_screen.dart';
import 'screens/premium_paywall_screen.dart'; // [NEW]

import 'providers/style_consultant_provider.dart';
import 'providers/favorites_provider.dart'; // ✅

import 'config/api_runtime.dart';
// import 'screens/api_settings_screen.dart'; // Removed

// Seller screens
import 'screens/vogue_seller_home_screen.dart'; // [NEW]
import 'screens/vogue_seller_products_screen.dart'; // [NEW]
import 'screens/vogue_seller_orders_screen.dart'; // [NEW]
import 'screens/vogue_seller_stores_screen.dart'; // [NEW]
import 'screens/vogue_add_product_screen.dart'; // [NEW]
import 'screens/vogue_seller_analytics_screen.dart'; // [NEW]

import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/locale_provider.dart';
import 'l10n/app_localizations.dart';

// ... imports ...

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiRuntime.init();

  // [NEW] Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final catalogProvider = CatalogProvider();
  await catalogProvider.init();

  final looksProvider = LooksProvider();
  await looksProvider.load();
  
  final marketplaceProvider = MarketplaceProvider();
  await marketplaceProvider.loadMarketplace();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => catalogProvider),
        ChangeNotifierProvider(create: (_) => looksProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthStorage())..bootstrap()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => marketplaceProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BuyerOrdersProvider()),
        ChangeNotifierProvider(create: (_) => StyleConsultantProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()..load()),
        // [NEW] Locale Provider
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const OutfitApp(),
    ),
  );
}

class OutfitApp extends StatelessWidget {
  const OutfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    // [NEW] Consumer to listen for language changes
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Waura',
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          
          // [NEW] Localization Setup
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('ru', ''),
            Locale('kk', ''),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
             // Check if the current device locale is supported
             for (var supportedLocale in supportedLocales) {
               if (supportedLocale.languageCode == locale?.languageCode) {
                 return supportedLocale;
               }
             }
             // If the locale of the device is not supported, use the first one
             return supportedLocales.first; // Default to EN
          },

          routes: {
            StartGateScreen.route: (_) => const StartGateScreen(),
            LoginScreen.route: (_) => const LoginScreen(),
            RegisterScreen.route: (_) => const RegisterScreen(),
            MainScreen.route: (_) => const MainScreen(),
            StyleSearchScreen.route: (_) => const StyleSearchScreen(),
            AddClothingScreen.route: (_) => const AddClothingScreen(),
            // CatalogScreen.route: (_) => const CatalogScreen(), // Removed
            StoreCatalogScreen.route: (_) => const StoreCatalogScreen(),
            VogueTryOnScreen.route: (context) => const VogueTryOnScreen(),
            MyLooksScreen.route: (_) => const MyLooksScreen(),
            // ApiSettingsScreen.route: (_) => const ApiSettingsScreen(), // Removed
            BuyerOrdersScreen.route: (_) => const BuyerOrdersScreen(),
            StyleConsultantScreen.route: (_) => const StyleConsultantScreen(),
            OutfitBuilderScreen.route: (_) => const OutfitBuilderScreen(),
            InspirationFeedScreen.route: (_) => const InspirationFeedScreen(),
            PremiumPaywallScreen.route: (_) => const PremiumPaywallScreen(), // [NEW]
            '/vogue-seller/home': (_) => const VogueSellerHomeScreen(),
            '/vogue-seller/products': (_) => const VogueSellerProductsScreen(),
            '/vogue-seller/orders': (_) => const VogueSellerOrdersScreen(),
            '/vogue-seller/stores': (_) => const VogueSellerStoresScreen(),
            '/vogue-seller/analytics': (_) => const VogueSellerAnalyticsScreen(),
            '/vogue-seller/add-product': (_) => const VogueAddProductScreen(),
            CartScreen.route: (_) => const CartScreen(),
            CheckoutScreen.route: (_) => const CheckoutScreen(),
          },
          initialRoute: StartGateScreen.route,
        );
      },
    );
  }
}

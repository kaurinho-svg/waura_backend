import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/seller_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/buyer_orders_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'welcome_screen.dart';
import 'main_screen.dart';

class StartGateScreen extends StatefulWidget {
  static const route = '/';

  const StartGateScreen({super.key});

  @override
  State<StartGateScreen> createState() => _StartGateScreenState();
}

class _StartGateScreenState extends State<StartGateScreen> with SingleTickerProviderStateMixin {
  bool _navigated = false;
  String _status = ''; // Hidden by default (premium feel)
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); 

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _updateStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_navigated) return;

    final auth = context.watch<AuthProvider>();
    if (!auth.isBootstrapped) return;

    _navigated = true;
    
    Future.delayed(const Duration(milliseconds: 1500), () {
       _checkAuth(auth);
    });
  }

  Future<void> _checkAuth(AuthProvider auth) async {
    if (!mounted) return;

      if (auth.isLoggedIn) {
        final user = auth.user!;
        _updateStatus(context.tr('splash_loading_data'));
        
        if (user.isSeller) {
          final sellerProvider = context.read<SellerProvider>();
          try {
            await sellerProvider.init(user.email).timeout(const Duration(seconds: 3));
          } catch (e) {
            debugPrint('Seller init skipped: $e');
             // _updateStatus(context.tr('splash_seller_init_error')); // Optional
          }
          
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/vogue-seller/home');
        } else {
          final cartProvider = context.read<CartProvider>();
          final buyerOrdersProvider = context.read<BuyerOrdersProvider>();
          
          try {
             await Future.wait([
               cartProvider.init(user.email),
               buyerOrdersProvider.init(user.email),
             ]).timeout(const Duration(seconds: 3));
          } catch (e) {
             debugPrint('Buyer init skipped: $e');
             // _updateStatus(context.tr('splash_buyer_init_error')); // Optional
          }
          
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(MainScreen.route);
        }
      } else {
        if (!mounted) return;
        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen())
          );
        } catch (e) {
          _updateStatus(context.tr('splash_nav_error', params: {'error': e.toString()}));
        }
      }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                      ? [const Color(0xFF1A1A1A), const Color(0xFF000000)]
                      : [const Color(0xFFF9F9F9), const Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),
          
          // Centered Logo
          Center(
            child: FadeTransition(
              opacity: _scaleAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // Logo Image
                     Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.asset(
                            'assets/icon/app_icon.png', // Updated to new icon path
                            fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Icon(Icons.checkroom, size: 50, color: theme.colorScheme.primary),
                          ),
                        ),
                     ),
                     const SizedBox(height: 24),
                     // Brand Name
                     Text(
                       context.tr('app_title'), // "Waura"
                       style: GoogleFonts.playfairDisplay(
                         fontSize: 32,
                         fontWeight: FontWeight.w600,
                         letterSpacing: 4.0,
                         color: theme.colorScheme.primary,
                       ),
                     ),
                     const SizedBox(height: 8),
                     // Tagline
                     Text(
                       "PERSONAL AI STYLIST",
                       style: GoogleFonts.lato(
                         fontSize: 10,
                         fontWeight: FontWeight.w500,
                         letterSpacing: 3.0,
                         color: theme.colorScheme.primary.withOpacity(0.6),
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ),
          
          // Status Text
          if (_status.isNotEmpty)
            Positioned(
              bottom: 40,
              left: 0, 
              right: 0,
              child: Center(
                child: Text(
                  _status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


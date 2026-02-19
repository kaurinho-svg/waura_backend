import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/app_user.dart';

class PremiumPaywallScreen extends StatefulWidget {
  static const route = '/premium-paywall';

  // Optional: redirect to a specific route after success
  final String? redirectRoute;

  const PremiumPaywallScreen({super.key, this.redirectRoute});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  bool _isLoading = false;

  Future<void> _buyPremium() async {
    setState(() => _isLoading = true);
    
    // MOCK PAYMENT PROCESS
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Upgrade user in local state (in real app, this happens via webhook -> DB -> App)
    // For now, we simulate it by updating the provider directly if possible, 
    // BUT since AuthProvider updates local state based on DB, we might need a 
    // cheat-code in AuthProvider or just a manual re-fetch.
    
    // For this MVP, let's pretend we called an API to upgrade.
    // We will call a "mock upgrade" function we'll add to AuthProvider for testing.
    final auth = context.read<AuthProvider>();
    
    // Since we don't have a real backend endpoint for this yet in the provider,
    // we'll just update the user locally to show it works.
    // In a real app, you'd call Supabase Function 'upgrade_user'.
    
    final newUser = auth.user!.copyWith(isPremium: true);
    // This is a "hack" for the demo. In reality, we should update DB.
    // However, AuthProvider.updateUser updates DB 'profiles' table.
    // So if we add 'is_premium' to profiles, this might actually work persistent!
    
    // TRY to update via existing updateUser method (if we update it to handle premium)
    // OR just use a temporary local set for the demo session.
    
    // Let's assume we want to persist it.
    try {
        // We need to allow updating is_premium in AuthProvider.updateUser
        // or create a special method. Let's create a special method in AuthProvider next.
        await auth.upgradeToPremiumMock(); 
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Premium! 💎')),
        );
        
        if (widget.redirectRoute != null) {
             Navigator.of(context).pushReplacementNamed(widget.redirectRoute!);
        } else {
             Navigator.of(context).pop(true); // Return success
        }
        
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: $e')),
        );
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image (Optional)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/images/paywall_bg.jpg', // Ensure you have an asset or standard bg
                fit: BoxFit.cover,
                errorBuilder: (_,__,___) => Container(color: Colors.deepPurple.shade900),
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Close Button
                   Align(
                     alignment: Alignment.topRight,
                     child: IconButton(
                       icon: const Icon(Icons.close, color: Colors.white),
                       onPressed: () => Navigator.of(context).pop(),
                     ),
                   ),
                   const SizedBox(height: 20),
                   
                   const Text(
                     "UNLOCK\nPRO STYLE",
                     style: TextStyle(
                       color: Colors.white,
                       fontSize: 42,
                       fontWeight: FontWeight.w900,
                       height: 1.0,
                       letterSpacing: -1.0,
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     "Get access to studio-quality AI try-ons and video generation.",
                     style: TextStyle(
                       color: Colors.white.withOpacity(0.8),
                       fontSize: 16,
                     ),
                   ),
                   
                   const Spacer(),
                   
                   _FeatureRow(icon: Icons.high_quality, title: "Pro Resolution", subtitle: "4K detailed textures & fabrics"),
                   const SizedBox(height: 20),
                   _FeatureRow(icon: Icons.videocam, title: "Video Try-On", subtitle: "See yourself moving in new outfits"),
                   const SizedBox(height: 20),
                   _FeatureRow(icon: Icons.bolt, title: "Priority Processing", subtitle: "Skip the line"),
                   
                   const Spacer(),
                   
                   // Price
                   const Center(
                     child: Text(
                       "\$9.99 / month",
                       style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                     ),
                   ),
                   const SizedBox(height: 20),
                   
                   // Button
                   SizedBox(
                     width: double.infinity,
                     height: 56,
                     child: ElevatedButton(
                       onPressed: _isLoading ? null : _buyPremium,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.white,
                         foregroundColor: Colors.black,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                       ),
                       child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("SUBSCRIBE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     ),
                   ),
                   const SizedBox(height: 12),
                   const Center(
                     child: Text(
                       "Cancel anytime. Terms apply.",
                       style: TextStyle(color: Colors.grey, fontSize: 12),
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

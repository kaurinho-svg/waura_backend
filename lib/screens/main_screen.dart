import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'inspiration_feed_screen.dart';
import 'vogue_home_screen.dart';
import 'wardrobe_wrapper_screen.dart'; // Created earlier
import 'style_consultant_screen.dart';
// import 'profile_screen.dart'; // Created earlier
import 'vogue_profile_screen.dart';
import '../providers/style_consultant_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]

class MainScreen extends StatefulWidget {
  static const route = '/main';
  
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const VogueHomeScreen(),
    const WardrobeWrapperScreen(),
    StyleConsultantScreen(isRoot: true),
    const VogueProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = theme.colorScheme.secondary;
    final charcoal = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Stack is used to keep state of screens alive if we wanted (using IndexesStack),
      // but standard body switch is fine for now unless we need to preserve scroll position.
      // Let's use IndexedStack for better UX (so chat doesn't clear).
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.auto_awesome_mosaic_outlined,
                  activeIcon: Icons.auto_awesome_mosaic,
                  label: context.tr('nav_home'),
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavBarItem(
                  icon: Icons.checkroom_outlined,
                  activeIcon: Icons.checkroom,
                  label: context.tr('nav_wardrobe'),
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),

                // Center Action - Try On
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/vogue-try-on'),
                  child: Container(
                    width: 48, 
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary, 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.secondary.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.checkroom, color: Colors.white, size: 24),
                  ),
                ),
                _NavBarItem(
                  icon: Icons.psychology_outlined,
                  activeIcon: Icons.psychology,
                  label: context.tr('nav_stylist'),
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavBarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: context.tr('nav_profile'),
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Custom Navigation Bar Item with animation
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.primary.withOpacity(0.4);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 5 : 0,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 2),
            // Icon with scale animation
            AnimatedScale(
              scale: isActive ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

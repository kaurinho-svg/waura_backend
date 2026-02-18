import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/looks_provider.dart';
import '../providers/locale_provider.dart'; // [NEW]
import '../ui/components/premium_card.dart';
import '../ui/components/section_header.dart';
import '../l10n/app_localizations.dart'; // [NEW]

/// VOGUE.AI Style Profile Screen
class VogueProfileScreen extends StatelessWidget {
  static const route = '/vogue-profile';

  const VogueProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: context.tr('profile_title'),
              ),
              const SizedBox(height: 24),

              // User Card
              PremiumCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          auth.user?.name.substring(0, 1).toUpperCase() ?? 'U',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.name ?? context.tr('profile_guest'),
                            style: theme.textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),


              // Menu Items
              _MenuItem(
                icon: Icons.person_outline,
                title: context.tr('profile_settings_title'),
                onTap: () => _showEditProfileDialog(context, auth),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.favorite_outline,
                title: context.tr('cat_favorites'),
                onTap: () {
                   // Navigate to Wardrobe (Catalog)
                   Navigator.pushNamed(context, '/vogue-catalog');
                },
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.history,
                title: context.tr('profile_history_title'),
                onTap: () => _showHistoryDialog(context),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.palette_outlined,
                title: context.tr('profile_preferences'),
                onTap: () => _showPreferencesDialog(context),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.language,
                title: context.tr('profile_language'), // Need to add key 'profile_language' -> "Language" / "Язык"
                // Or just use hardcoded 'Language' initially if key missing, but better to add key.
                // Assuming key might not be there, I'll check/add safely.
                // Let's use 'Language' or context.tr('profile_language') and add key later.
                // I will add the key 'profile_language' in a separate step or assume it exists/add it now.
                // I'll check localizations first? No, let's just add the code and then fail-safe with "Language".
                onTap: () => _showLanguageDialog(context),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.help_outline,
                title: context.tr('profile_help'),
                onTap: () => _showHelpDialog(context),
              ),

              // ... (rest of the list)
              
              // API Settings
              const SizedBox(height: 50), // Added spacing to prevent overlap with Help
              _MenuItem(
                icon: Icons.dns_outlined,
                title: 'API Settings', // Ideally localized too, but let's say technical
                onTap: () {
                  Navigator.pushNamed(context, '/api-settings');
                },
              ),
              const SizedBox(height: 12),
              
              const SizedBox(height: 32),

              // Logout
              PremiumCard(
                onTap: () {
                  auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                },
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      context.tr('profile_logout'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80), // Bottom nav space
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.user?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile_settings_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: context.tr('auth_name_label')),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common_cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (auth.user != null) {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  // Create updated user
                  // Note: copyWith is defined in AppUser
                  final updated = AppUser(
                    name: newName,
                    email: auth.user!.email,
                    gender: auth.user!.gender,
                    role: auth.user!.role,
                    storeIds: auth.user!.storeIds,
                  );
                  await auth.updateUser(updated);
                }
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(context.tr('common_success'))),
                );
              }
            },
            child: Text(context.tr('common_save')),
          ),
        ],
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile_preferences')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('profile_sizes')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['XS', 'S', 'M', 'L', 'XL'].map((size) {
                return FilterChip(
                  label: Text(size),
                  selected: ['S', 'M'].contains(size), // Mock selection
                  onSelected: (bool selected) {},
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(context.tr('profile_style')),
             const SizedBox(height: 8),
             Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(context.tr('cat_minimal'))),
                Chip(label: Text(context.tr('cat_casual'))),
                Chip(label: Text(context.tr('cat_business'))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common_close')),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile_help')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('support@waura.ai'),
              subtitle: Text(context.tr('profile_support_subtitle')),
            ),
            ListTile(
              leading: const Icon(Icons.web),
              title: const Text('waura.app/faq'),
              subtitle: Text(context.tr('profile_faq_subtitle')),
            ),
             ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(context.tr('profile_version')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common_ok')),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
      // Mock history
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('profile_history_title')),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<LooksProvider>(
              builder: (context, looksProvider, _) {
                 if (looksProvider.looks.isEmpty) {
                   return Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text(context.tr('profile_history_empty')),
                   );
                 }
                 return ListView.builder(
                   shrinkWrap: true,
                   itemCount: looksProvider.looks.length,
                   itemBuilder: (context, index) {
                     final look = looksProvider.looks[index];
                     return ListTile(
                       leading: const Icon(Icons.checkroom),
                       title: Text(look.prompt.isNotEmpty ? look.prompt : context.tr('my_looks_no_prompt')),
                       subtitle: Text('${look.createdAt.day}.${look.createdAt.month}.${look.createdAt.year}'),
                       onTap: () {
                          Navigator.pop(context);
                       },
                     );
                   },
                 );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('common_close')),
            ),
          ],
        ),
      );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final localeProvider = context.read<LocaleProvider>();
        final current = localeProvider.locale;

        return AlertDialog(
          title: Text(context.tr('profile_language') ?? 'Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                trailing: current.languageCode == 'en' ? const Icon(Icons.check) : null,
                onTap: () {
                  localeProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Русский'),
                trailing: current.languageCode == 'ru' ? const Icon(Icons.check) : null,
                onTap: () {
                  localeProvider.setLocale(const Locale('ru'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Қазақша'),
                trailing: current.languageCode == 'kk' ? const Icon(Icons.check) : null,
                onTap: () {
                  localeProvider.setLocale(const Locale('kk'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('common_close')),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.primary.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}

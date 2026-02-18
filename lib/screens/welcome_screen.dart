import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart'; // [NEW]
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  static const route = '/welcome';
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Language Switcher
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.language),
                onPressed: () => _showLanguageDialog(context),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                ),
              ),
            ),
            
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logо
                      Center(
                        child: Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/images/logo_waura.png', 
                            color: Colors.white,
                            errorBuilder: (_,__,___) => const Icon(Icons.checkroom, color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        context.tr('welcome_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('welcome_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, RegisterScreen.route),
                        child: Text(context.tr('welcome_register')),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
                        child: Text(context.tr('welcome_login')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        // Need to import provider and locale_provider
        // Assuming imports are added or will be added
        final localeProvider = context.read<LocaleProvider>();
        final current = localeProvider.locale;

        return AlertDialog(
          title: Text(context.tr('profile_language') ?? 'Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageOption(
                title: 'English',
                code: 'en',
                selected: current.languageCode == 'en',
                onSelect: () => localeProvider.setLocale(const Locale('en')),
              ),
              _LanguageOption(
                title: 'Русский',
                code: 'ru',
                selected: current.languageCode == 'ru',
                onSelect: () => localeProvider.setLocale(const Locale('ru')),
              ),
              _LanguageOption(
                title: 'Қазақша',
                code: 'kk',
                selected: current.languageCode == 'kk',
                onSelect: () => localeProvider.setLocale(const Locale('kk')),
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

class _LanguageOption extends StatelessWidget {
  final String title;
  final String code;
  final bool selected;
  final VoidCallback onSelect;

  const _LanguageOption({
    required this.title,
    required this.code,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: selected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        onSelect();
        Navigator.pop(context);
      },
    );
  }
}

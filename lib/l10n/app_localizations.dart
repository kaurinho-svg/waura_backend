import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    try {
      String jsonString = await rootBundle.loadString('assets/translations/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      return true;
    } catch (e) {
      debugPrint('Error loading translation for ${locale.languageCode}: $e');
      // Fallback or empty
      _localizedStrings = {};
      return false;
    }
  }

  String translate(String key, {Map<String, String>? params}) {
    String value = _localizedStrings[key] ?? key; // Return key if not found
    
    if (params != null) {
      params.forEach((key, paramValue) {
        value = value.replaceAll('{$key}', paramValue);
      });
    }
    
    return value;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru', 'kk'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Extension for easier access
extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    return AppLocalizations.of(this)?.translate(key, params: params) ?? key;
  }
}

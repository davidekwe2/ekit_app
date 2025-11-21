import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class LanguageService extends ChangeNotifier {
  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  LanguageService() {
    _loadLanguagePreference();
    // Listen to auth state changes to reload language when user changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadLanguagePreference();
    });
  }

  String _getLanguageKey() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return 'language_${user.uid}';
    }
    return 'language_guest';
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getLanguageKey();
    final languageCode = prefs.getString(key);
    
    if (languageCode != null) {
      final parts = languageCode.split('_');
      if (parts.length == 2) {
        _locale = Locale(parts[0], parts[1]);
      } else if (parts.length == 1) {
        // If only language code, use default country code
        final defaultCountries = {
          'en': 'US',
          'es': 'ES',
          'fr': 'FR',
          'de': 'DE',
          'it': 'IT',
          'pt': 'BR',
          'ru': 'RU',
          'ar': 'SA',
          'zh': 'CN',
          'ja': 'JP',
          'ko': 'KR',
          'hi': 'IN',
          'nl': 'NL',
          'sv': 'SE',
          'pl': 'PL',
        };
        final countryCode = defaultCountries[parts[0]] ?? 'US';
        _locale = Locale(parts[0], countryCode);
      } else {
        _locale = const Locale('en', 'US');
      }
    } else {
      _locale = const Locale('en', 'US'); // Default to English
    }
    notifyListeners();
  }

  Future<void> setLanguage(Locale locale) async {
    // Ensure locale has country code
    final defaultCountries = {
      'en': 'US',
      'es': 'ES',
      'fr': 'FR',
      'de': 'DE',
      'it': 'IT',
      'pt': 'BR',
      'ru': 'RU',
      'ar': 'SA',
      'zh': 'CN',
      'ja': 'JP',
      'ko': 'KR',
      'hi': 'IN',
      'nl': 'NL',
      'sv': 'SE',
      'pl': 'PL',
    };
    
    final countryCode = locale.countryCode ?? defaultCountries[locale.languageCode] ?? 'US';
    final localeWithCountry = Locale(locale.languageCode, countryCode);
    
    if (_locale != localeWithCountry) {
      _locale = localeWithCountry;
      final prefs = await SharedPreferences.getInstance();
      final key = _getLanguageKey();
      await prefs.setString(key, '${locale.languageCode}_$countryCode');
      notifyListeners();
    }
  }

  /// Reload language preference when user changes
  Future<void> reloadForUser() async {
    await _loadLanguagePreference();
  }

  static List<Locale> get supportedLocales => [
    const Locale('en', 'US'), // English
    const Locale('es', 'ES'), // Spanish
    const Locale('fr', 'FR'), // French
    const Locale('de', 'DE'), // German
    const Locale('it', 'IT'), // Italian
    const Locale('pt', 'BR'), // Portuguese
    const Locale('ru', 'RU'), // Russian
    const Locale('ar', 'SA'), // Arabic
    const Locale('zh', 'CN'), // Chinese
    const Locale('ja', 'JP'), // Japanese
    const Locale('ko', 'KR'), // Korean
    const Locale('hi', 'IN'), // Hindi
    const Locale('nl', 'NL'), // Dutch
    const Locale('sv', 'SE'), // Swedish
    const Locale('pl', 'PL'), // Polish
  ];

  String getLanguageName(Locale locale) {
    final names = {
      'en_US': 'English',
      'es_ES': 'Español',
      'fr_FR': 'Français',
      'de_DE': 'Deutsch',
      'it_IT': 'Italiano',
      'pt_BR': 'Português',
      'ru_RU': 'Русский',
      'ar_SA': 'العربية',
      'zh_CN': '中文',
      'ja_JP': '日本語',
      'ko_KR': '한국어',
      'hi_IN': 'हिन्दी',
      'nl_NL': 'Nederlands',
      'sv_SE': 'Svenska',
      'pl_PL': 'Polski',
    };
    final key = '${locale.languageCode}_${locale.countryCode ?? 'US'}';
    return names[key] ?? locale.languageCode.toUpperCase();
  }
}


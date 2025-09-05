import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  
  Locale _locale = const Locale('en', '');
  
  Locale get locale => _locale;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  // Load saved locale from SharedPreferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_localeKey);
      
      if (localeCode != null) {
        _locale = Locale(localeCode, '');
        notifyListeners();
      }
    } catch (e) {
      print('Error loading locale: $e');
    }
  }
  
  // Change locale and save to SharedPreferences
  Future<void> setLocale(Locale locale) async {
    try {
      _locale = locale;
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (e) {
      print('Error saving locale: $e');
    }
  }
  
  // Toggle between English and Turkish
  Future<void> toggleLocale() async {
    final newLocale = _locale.languageCode == 'en' 
        ? const Locale('tr', '')
        : const Locale('en', '');
    await setLocale(newLocale);
  }
  
  // Check if current locale is English
  bool get isEnglish => _locale.languageCode == 'en';
  
  // Check if current locale is Turkish
  bool get isTurkish => _locale.languageCode == 'tr';
  
  // Get locale display name
  String get localeDisplayName {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'tr':
        return 'Türkçe';
      default:
        return 'English';
    }
  }
  
  // Get available locales
  List<Locale> get supportedLocales => const [
    Locale('en', ''),
    Locale('tr', ''),
  ];
  
  // Get locale display names
  Map<String, String> get localeDisplayNames => {
    'en': 'English',
    'tr': 'Türkçe',
  };
}
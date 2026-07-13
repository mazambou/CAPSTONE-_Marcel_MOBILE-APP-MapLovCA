import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  LocaleService._();
  static final instance = LocaleService._();
  static const _key = 'maplov_locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> load() async {
    final code = (await SharedPreferences.getInstance()).getString(_key);
    if (code == 'fr' || code == 'en') _locale = Locale(code!);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'fr') return;
    _locale = Locale(code);
    await (await SharedPreferences.getInstance()).setString(_key, code);
    notifyListeners();
  }
}

class MapLovLocalizations {
  const MapLovLocalizations(this.locale);
  final Locale locale;

  static MapLovLocalizations of(BuildContext context) =>
      Localizations.of<MapLovLocalizations>(context, MapLovLocalizations) ??
      const MapLovLocalizations(Locale('en'));

  static const delegate = _MapLovLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'en': {
      'discover': 'Discover',
      'messages': 'Messages',
      'map': 'Map',
      'likes': 'Likes',
      'profile': 'Profile',
      'filters': 'Filters',
      'notifications': 'Notifications',
      'language': 'Language',
      'apply_language': 'Apply language',
    },
    'fr': {
      'discover': 'Découvrir',
      'messages': 'Messages',
      'map': 'Carte',
      'likes': 'J’aime',
      'profile': 'Profil',
      'filters': 'Filtres',
      'notifications': 'Notifications',
      'language': 'Langue',
      'apply_language': 'Appliquer la langue',
    },
  };

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
}

class _MapLovLocalizationsDelegate
    extends LocalizationsDelegate<MapLovLocalizations> {
  const _MapLovLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const ['en', 'fr'].contains(locale.languageCode);
  @override
  Future<MapLovLocalizations> load(Locale locale) =>
      SynchronousFuture(MapLovLocalizations(locale));
  @override
  bool shouldReload(covariant LocalizationsDelegate<MapLovLocalizations> old) =>
      false;
}

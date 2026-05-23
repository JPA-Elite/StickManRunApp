import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const String _darkModeKey = 'darkMode';

  final SharedPreferences prefs;

  bool _darkMode = false;

  ThemeController({required this.prefs}) {
    _darkMode = prefs.getBool(_darkModeKey) ?? false;
  }

  bool get darkMode => _darkMode;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF1D4ED8), // blue-ish
        scaffoldBackgroundColor: Colors.grey.shade50,
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF60A5FA), // light blue-ish
        scaffoldBackgroundColor: const Color(0xFF111827), // gray-900
      );

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    prefs.setBool(_darkModeKey, _darkMode);
    notifyListeners();
  }
}

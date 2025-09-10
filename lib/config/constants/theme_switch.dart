import "package:flowchart_thesis/config/constants/themes.dart";
import "package:flutter/material.dart";
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'theme_mode'; // 'light' | 'dark'

  final SharedPreferences _prefs;
  ThemeData _themeMode = lightmode;

  ThemeProvider(this._prefs) {
    // Ripristina il tema salvato, default light
    final saved = _prefs.getString(_prefsKey);
    if (saved == 'dark') {
      _themeMode = darkmode;
    } else if (saved == 'light') {
      _themeMode = lightmode;
    }
  }

  ThemeData get themeData => _themeMode;

  void toggleTheme() {
    if (_themeMode.brightness == Brightness.light) {
      _themeMode = darkmode;
      _prefs.setString(_prefsKey, 'dark');
    } else {
      _themeMode = lightmode;
      _prefs.setString(_prefsKey, 'light');
    }
    notifyListeners();
  }

  void setTheme(ThemeData theme) {
    _themeMode = theme;
    _prefs.setString(_prefsKey, theme.brightness == Brightness.dark ? 'dark' : 'light');
    notifyListeners();
  }
}
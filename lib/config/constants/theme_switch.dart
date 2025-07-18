import "package:flowchart_thesis/config/constants/themes.dart";
import "package:flutter/material.dart";

class ThemeProvider with ChangeNotifier {
  ThemeData _themeMode = lightmode;
  ThemeData get themeData => _themeMode;
  void toggleTheme() {
    if (_themeMode == lightmode) {
      _themeMode = darkmode;
    } else {
      _themeMode = lightmode;
    }
    notifyListeners();
  }
  void setTheme(ThemeData theme) {
    _themeMode = theme;
    notifyListeners();
  }
}
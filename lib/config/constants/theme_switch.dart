import 'package:flowchart_thesis/config/constants/themes.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  final SharedPreferences _prefs;
  FluentThemeData _themeData = lightmode;

  ThemeProvider(this._prefs) {
    final saved = _prefs.getString(_prefsKey);
    if (saved == 'dark') {
      _themeData = darkmode;
    } else if (saved == 'light') {
      _themeData = lightmode;
    }
  }

  FluentThemeData get themeData => _themeData;

  void toggleTheme() {
    if (_themeData.brightness == Brightness.light) {
      _themeData = darkmode;
      _prefs.setString(_prefsKey, 'dark');
    } else {
      _themeData = lightmode;
      _prefs.setString(_prefsKey, 'light');
    }
    notifyListeners();
  }

  void setTheme(FluentThemeData theme) {
    _themeData = theme;
    _prefs.setString(
        _prefsKey, theme.brightness == Brightness.dark ? 'dark' : 'light');
    notifyListeners();
  }
}
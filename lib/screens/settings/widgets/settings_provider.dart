import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyAutoSave = 'key_auto_save_enabled';

  final SharedPreferences _prefs;

  late bool _autoSaveEnabled;

  SettingsProvider(this._prefs) {
    _autoSaveEnabled = _prefs.getBool(keyAutoSave) ?? true;
  }

  bool get autoSaveEnabled => _autoSaveEnabled;

  Future<void> updateAutoSave(bool newValue) async {
    if (_autoSaveEnabled == newValue) return;
    _autoSaveEnabled = newValue;
    await _prefs.setBool(keyAutoSave, newValue);
    notifyListeners();
  }

  Future<void> resetAll() async {
    _autoSaveEnabled = true;
    await _prefs.setBool(keyAutoSave, true);
    notifyListeners();
  }
}
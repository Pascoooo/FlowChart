// dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExportPreference { alwaysAsk, local, drive }

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  static const String _exportPrefKey = 'export_preference';

  ExportPreference _exportPreference = ExportPreference.alwaysAsk;
  ExportPreference get exportPreference => _exportPreference;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final int prefIndex = _prefs.getInt(_exportPrefKey) ?? 0;
    _exportPreference = ExportPreference.values[prefIndex];
    notifyListeners();
  }

  Future<void> updateExportPreference(ExportPreference newPreference) async {
    if (_exportPreference == newPreference) return;
    _exportPreference = newPreference;
    await _prefs.setInt(_exportPrefKey, newPreference.index);
    notifyListeners();
  }
}

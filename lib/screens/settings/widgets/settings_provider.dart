// pascoooo/flowchart/FlowChart-rework-flowchart/lib/screens/settings/widgets/settings_provider.dart

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

    _exportPreference = ExportPreference.values[_prefs.getInt(_exportPrefKey) ?? 0];

    notifyListeners();
  }

  // ... (metodi updateExportPreference e updateLocalExecutorPort invariati) ...
  Future<void> updateExportPreference(ExportPreference newPreference) async {
    if (_exportPreference == newPreference) return;
    _exportPreference = newPreference;
    await _prefs.setInt(_exportPrefKey, newPreference.index);
    notifyListeners();
  }
}
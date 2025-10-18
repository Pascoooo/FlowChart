// pascoooo/flowchart/FlowChart-rework-flowchart/lib/screens/settings/widgets/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExportPreference { alwaysAsk, local, drive }

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  static const String _exportPrefKey = 'export_preference';
  static const String _dontShowGridDialogKey = 'dont_show_grid_dialog';

  ExportPreference _exportPreference = ExportPreference.alwaysAsk;
  ExportPreference get exportPreference => _exportPreference;

  bool _dontShowGridDialogAgain = false;
  bool get dontShowGridDialogAgain => _dontShowGridDialogAgain;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _exportPreference = ExportPreference.values[_prefs.getInt(_exportPrefKey) ?? 0];
    _dontShowGridDialogAgain = _prefs.getBool(_dontShowGridDialogKey) ?? false;

    notifyListeners();
  }

  Future<void> updateExportPreference(ExportPreference newPreference) async {
    if (_exportPreference == newPreference) return;
    _exportPreference = newPreference;
    await _prefs.setInt(_exportPrefKey, newPreference.index);
    notifyListeners();
  }

  Future<void> setDontShowGridDialogAgain(bool value) async {
    if (_dontShowGridDialogAgain == value) return;
    _dontShowGridDialogAgain = value;
    await _prefs.setBool(_dontShowGridDialogKey, value);
    notifyListeners();
  }
}
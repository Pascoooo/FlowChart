// lib/config/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum per definire le possibili scelte di esportazione
enum ExportPreference { alwaysAsk, local, drive }

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  static const String _exportPrefKey = 'export_preference';

  ExportPreference _exportPreference = ExportPreference.alwaysAsk;
  ExportPreference get exportPreference => _exportPreference;

  SettingsProvider() {
    _loadSettings();
  }

  // Carica le preferenze salvate all'avvio dell'app
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final int prefIndex = _prefs.getInt(_exportPrefKey) ?? 0;
    _exportPreference = ExportPreference.values[prefIndex];
    notifyListeners();
  }

  // Aggiorna e salva la nuova preferenza
  Future<void> updateExportPreference(ExportPreference newPreference) async {
    if (_exportPreference == newPreference) return;

    _exportPreference = newPreference;
    await _prefs.setInt(_exportPrefKey, newPreference.index);
    notifyListeners();
  }
}
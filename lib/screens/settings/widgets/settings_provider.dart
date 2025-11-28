/// Settings provider per le preferenze di esportazione e dialoghi di griglia.
/// Usa SharedPreferences per persistere le scelte dell'utente e notifica la UI
/// quando cambiano, così la UI può reagire in modo reattivo.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  static const String _dontShowGridDialogKey = 'dont_show_grid_dialog';

  bool _dontShowGridDialogAgain = false;
  bool get dontShowGridDialogAgain => _dontShowGridDialogAgain;

  SettingsProvider() {
    _loadSettings();
  }

  /// Carica e ripristina solo le preferenze ancora supportate (es. dialog della griglia).
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _dontShowGridDialogAgain = _prefs.getBool(_dontShowGridDialogKey) ?? false;
    notifyListeners();
  }

  /// Imposta la preferenza di non mostrare più l'avviso griglia,
  /// persiste la scelta e notifica i listener interessati.
  Future<void> setDontShowGridDialogAgain(bool value) async {
    if (_dontShowGridDialogAgain == value) return;
    _dontShowGridDialogAgain = value;
    await _prefs.setBool(_dontShowGridDialogKey, value);
    notifyListeners();
  }
}

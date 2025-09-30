// pascoooo/flowchart/FlowChart-rework-flowchart/lib/screens/settings/widgets/settings_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExportPreference { alwaysAsk, local, drive }

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  static const String _exportPrefKey = 'export_preference';
  static const String _localExecutorPortKey = 'local_executor_port';
  static const String _useLocalExecutorKey = 'use_local_executor';
  // NUOVO: Chiave per tracciare se l'utente ha aperto la guida.
  static const String _hasClickedDockerInfoKey = 'has_clicked_docker_info';

  ExportPreference _exportPreference = ExportPreference.alwaysAsk;
  ExportPreference get exportPreference => _exportPreference;

  String _localExecutorPort = '8080';
  String get localExecutorPort => _localExecutorPort;

  bool _useLocalExecutor = false;
  bool get useLocalExecutor => _useLocalExecutor;

  // NUOVO: Stato per la visibilità dei controlli avanzati.
  bool _hasClickedDockerInfo = false;
  bool get hasClickedDockerInfo => _hasClickedDockerInfo;

  String get localExecutorUrl =>
      _useLocalExecutor && _localExecutorPort.trim().isNotEmpty
          ? 'http://127.0.0.1:$_localExecutorPort'
          : '';

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    _exportPreference = ExportPreference.values[_prefs.getInt(_exportPrefKey) ?? 0];
    _localExecutorPort = _prefs.getString(_localExecutorPortKey) ?? '8080';
    _useLocalExecutor = _prefs.getBool(_useLocalExecutorKey) ?? false;
    // NUOVO: Carica lo stato della guida.
    _hasClickedDockerInfo = _prefs.getBool(_hasClickedDockerInfoKey) ?? false;

    notifyListeners();
  }

  // ... (metodi updateExportPreference e updateLocalExecutorPort invariati) ...
  Future<void> updateExportPreference(ExportPreference newPreference) async {
    if (_exportPreference == newPreference) return;
    _exportPreference = newPreference;
    await _prefs.setInt(_exportPrefKey, newPreference.index);
    notifyListeners();
  }

  Future<void> updateLocalExecutorPort(String newPort) async {
    final trimmedPort = newPort.trim();
    if (_localExecutorPort == trimmedPort) return;
    _localExecutorPort = trimmedPort;
    await _prefs.setString(_localExecutorPortKey, trimmedPort);
    notifyListeners();
  }


  Future<void> updateUseLocalExecutor(bool value) async {
    if (_useLocalExecutor == value) return;
    _useLocalExecutor = value;
    await _prefs.setBool(_useLocalExecutorKey, value);
    notifyListeners();
  }

  // NUOVO: Metodo per registrare che l'utente ha letto la guida.
  Future<void> setDockerInfoClicked() async {
    if (_hasClickedDockerInfo) return;
    _hasClickedDockerInfo = true;
    await _prefs.setBool(_hasClickedDockerInfoKey, true);
    notifyListeners();
  }
}
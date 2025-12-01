import 'package:firebase_remote_config/firebase_remote_config.dart';


/// Servizio per gestire la configurazione di Gemini AI tramite Firebase Remote Config
class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();

  GeminiService._();

  String? _apiKey;
  bool _isInitialized = false;

  /// Inizializza il servizio caricando l'API key da Remote Config
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Configura impostazioni Remote Config
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Imposta valori di default
      await remoteConfig.setDefaults(const {
        'gemini_api_key': '',
        'gemini_enabled': true,
      });

      // Fetch e attiva i valori
      await remoteConfig.fetchAndActivate();

      // Leggi l'API key da Remote Config
      _apiKey = remoteConfig.getString('gemini_api_key');

      // Fallback a configurazione locale se Remote Config è vuota
      if (_apiKey == null || _apiKey!.isEmpty) {
      } else {
        print('🔑 API key caricata da Firebase Remote Config');
      }

      _isInitialized = true;
      print('✅ GeminiService inizializzato con successo');
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        print('   Modello: Gemini 2.0 Flash Lite');
        print('   Lunghezza chiave: ${_apiKey!.length} caratteri');
      } else {
        print('⚠️ Nessuna API key trovata - configura Remote Config o local_gemini_config.dart');
      }
    } catch (e) {
      print('⚠️ Errore inizializzazione Remote Config: $e');
    }
  }

  /// Restituisce l'API key se disponibile
  String? get apiKey => _apiKey;

  /// Verifica se il servizio è configurato e pronto
  bool get isConfigured => _isInitialized && _apiKey != null && _apiKey!.isNotEmpty;

  /// Verifica se Gemini è abilitato da Remote Config
  Future<bool> get isEnabled async {
    if (!_isInitialized) return false;
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      return remoteConfig.getBool('gemini_enabled');
    } catch (e) {
      return false;
    }
  }

  /// Ricarica la configurazione da Remote Config
  Future<void> refresh() async {
    _isInitialized = false;
    _apiKey = null;
    await initialize();
  }
}


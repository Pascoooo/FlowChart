import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un servizio per registrare gli aggiornamenti dei timestamp dei progetti nel localStorage del browser.
///
/// Questo approccio "offline-first" per il web minimizza le scritture su Firestore. Le aperture
/// dei progetti vengono registrate localmente e sincronizzate in batch all'avvio successivo dell'app.
class UpdateLoggerService {
  // Questa è la chiave che useremo per salvare i dati nel localStorage.
  static const _storageKey = 'pending_project_updates';

  /// Registra l'apertura di un progetto nel localStorage.
  Future<void> logProjectUpdate(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Legge la lista di aggiornamenti esistente
      final updates = await getPendingUpdates(isLogging: false); // Disattiva il log qui per evitare confusione

      // Aggiunge il nuovo aggiornamento
      updates.add({
        'projectId': projectId,
        'openedAt': DateTime.now().toIso8601String(),
      });

      // Converte la lista in una stringa JSON
      final jsonString = jsonEncode(updates);

      developer.log('Scrittura nel localStorage: $jsonString');

      // Salva la lista aggiornata
      await prefs.setString(_storageKey, jsonString);

    } catch (e) {
      developer.log('Errore durante la registrazione dell\'aggiornamento del progetto: $e', error: e);
    }
  }

  /// Legge e restituisce la lista di aggiornamenti pendenti dal localStorage.
  Future<List<Map<String, dynamic>>> getPendingUpdates({bool isLogging = true}) async {
    try {
      // <<< SOLUZIONE: Aggiunto un micro-ritardo >>>
      // Su web, questo assicura che il plugin SharedPreferences sia completamente inizializzato
      // prima di tentare di leggere i dati, risolvendo la race condition all'avvio.
      if (kIsWeb) {
        await Future.delayed(Duration.zero);
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null && jsonString.isNotEmpty) {
        if (isLogging) developer.log('Dati letti da localStorage: $jsonString');
        final data = jsonDecode(jsonString);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
      } else {
        if (isLogging) developer.log('Nessun dato pendente trovato in localStorage per la chiave: $_storageKey');
      }
    } catch (e) {
      developer.log('Errore critico nella lettura degli aggiornamenti pendenti: $e', error: e);
    }
    return [];
  }

  /// Cancella gli aggiornamenti pendenti dal localStorage.
  ///
  /// Viene chiamato dopo una sincronizzazione con Firestore andata a buon fine.
  Future<void> clearPendingUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      developer.log('Aggiornamenti pendenti cancellati con successo da localStorage.');
    } catch (e) {
      developer.log('Errore durante la cancellazione degli aggiornamenti pendenti: $e', error: e);
    }
  }

  Future<void> deletePendingUpdatesFile() async {
    await clearPendingUpdates();
  }
}


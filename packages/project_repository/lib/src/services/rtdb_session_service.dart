import 'package:file_repository/file_repository.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

/// Servizio dedicato alla gestione della sessione di lavoro "live"
/// su Firebase Realtime Database (RTDB).
class RtdbSessionService {
  final String uid;
  late final DatabaseReference _rtdbSessionRef;


  RtdbSessionService({required this.uid})
      : _rtdbSessionRef = FirebaseDatabase.instance.ref('sessions/$uid');


  // --- Workspace Session ---

  /// Ottiene uno snapshot completo di tutte le sessioni attive dell'utente.
  /// Restituisce i dati RTDB del nodo /sessions/{uid}.
  Future<DataSnapshot> getSessionSnapshot() => _rtdbSessionRef.get();

  /// Rimuove la sessione di un singolo progetto dal RTDB.
  /// Elimina tutti i dati sotto /sessions/{uid}/{projectId}.
  Future<void> removeProjectSession(String projectId) =>
      _rtdbSessionRef.child(projectId).remove();

  /// Rimuove tutte le sessioni dell'utente dal RTDB.
  /// Cancella completamente il nodo /sessions/{uid}.
  Future<void> clearAllSessions() => _rtdbSessionRef.remove();

  /// Avvia una nuova sessione di lavoro per un progetto.
  /// Cancella eventuali sessioni precedenti e salva i file iniziali su RTDB.
  Future<void> startSession(
      String projectId, Map<String, dynamic> filesData) async {
    await clearAllSessions();
    final projectSessionRef = _rtdbSessionRef.child(projectId);
    await projectSessionRef.set({
      'sessionTimestamp': DateTime.now().toIso8601String(),
      'files': filesData,
    });
  }

  // --- File nella Sessione Live ---

  /// Restituisce uno stream del contenuto live di un file.
  /// Emette aggiornamenti in tempo reale ogni volta che il contenuto cambia su RTDB.
  Stream<String?> liveFileContent(String projectId, String fileId) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .child('content')
        .onValue
        .map((event) => event.snapshot.value as String?);
  }

  /// Aggiorna il contenuto live di un file nella sessione RTDB.
  /// Le modifiche vengono propagate in tempo reale a tutti i listener attivi.
  Future<void> updateLiveFileContent(
      String projectId, String fileId, String content) =>
      _rtdbSessionRef
          .child(projectId)
          .child('files')
          .child(fileId)
          .child('content')
          .set(content);

  /// Aggiunge un nuovo file alla sessione RTDB corrente.
  /// Il file diventa immediatamente disponibile per editing live.
  Future<void> addFileToSession(String projectId, MyFile file) => _rtdbSessionRef
      .child(projectId)
      .child('files')
      .child(file.fileId)
      .set({'name': file.name, 'content': file.content});

  /// Rimuove un file dalla sessione RTDB.
  /// Se è l'ultimo file, rimuove l'intera sessione del progetto.
  Future<void> removeFileFromSession(String projectId, String fileId) async {
    final fileNode =
    _rtdbSessionRef.child(projectId).child('files').child(fileId);
    final sessionFilesSnapshot =
    await _rtdbSessionRef.child(projectId).child('files').get();
    if (sessionFilesSnapshot.exists &&
        (sessionFilesSnapshot.value as Map).length > 1) {
      await fileNode.remove();
    } else {
      await removeProjectSession(projectId);
    }
  }

  /// Rinomina un file nella sessione RTDB.
  /// Aggiorna solo il campo 'name' mantenendo il contenuto invariato.
  Future<void> renameFileInSession(
      String projectId, String fileId, String newName) =>
      _rtdbSessionRef
          .child(projectId)
          .child('files')
          .child(fileId)
          .update({'name': newName});

  /// Inizializza lo stato di debug nella sessione RTDB corrente.
  /// Salva le variabili iniziali e le dichiarazioni opzionali per il debugging.
  Future<void> initializeDebugSession(
    String projectId,
    Map<String, dynamic> initialVariables, {
    Map<String, Map<String, dynamic>> declaredVariables = const {},
  }) {
    final debugRef = _rtdbSessionRef.child(projectId).child('debugState');
    final Map<String, dynamic> payload = {
      'variables': initialVariables,
    };
    if (declaredVariables.isNotEmpty) {
      payload['declaredVariables'] = declaredVariables;
    }
    return debugRef.set(payload);
  }

  /// Aggiorna le variabili nello stato di debug della sessione corrente.
  /// Mergia i nuovi valori con quelli esistenti senza sovrascrivere tutto.
  Future<void> updateDebugVariables(String projectId, Map<String, dynamic> newValues) {
    return _rtdbSessionRef
        .child(projectId)
        .child('debugState')
        .child('variables')
        .update(newValues);
  }

  /// Ascolta le modifiche alle variabili di debug in tempo reale.
  /// Emette aggiornamenti ogni volta che le variabili cambiano durante il debugging.
  Stream<Map<String, dynamic>> watchDebugVariables(String projectId) {
    return _rtdbSessionRef
        .child(projectId)
        .child('debugState')
        .child('variables')
        .onValue
        .map((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return {};
    });
  }

  /// Rimuove lo stato di debug dalla sessione corrente.
  /// Cancella tutte le variabili e le dichiarazioni salvate per il debug.
  Future<void> clearDebugSession(String projectId) {
    return _rtdbSessionRef.child(projectId).child('debugState').remove();
  }

  /// Legge una sola volta lo stato corrente delle variabili di debug.
  /// Snapshot sincrono per ottenere i valori attuali senza stream.
  Future<Map<String, dynamic>> getCurrentDebugVariables(String projectId) async {
    final snapshot = await _rtdbSessionRef
        .child(projectId)
        .child('debugState')
        .child('variables')
        .get();

    if (snapshot.exists && snapshot.value != null) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }

    return {};
  }

  /// Legge le variabili dichiarate salvate nella sessione di debug.
  /// Restituisce le dichiarazioni con i loro metadati (tipo, scope, etc.).
  Future<Map<String, Map<String, dynamic>>> getDeclaredVariables(String projectId) async {
    final snapshot = await _rtdbSessionRef
        .child(projectId)
        .child('debugState')
        .child('declaredVariables')
        .get();

    if (snapshot.exists && snapshot.value != null) {
      final raw = Map<String, dynamic>.from(snapshot.value as Map);
      return raw.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    }
    return {};
  }
}
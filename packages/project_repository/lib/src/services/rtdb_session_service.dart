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
  Future<DataSnapshot> getSessionSnapshot() => _rtdbSessionRef.get();
  Future<void> removeProjectSession(String projectId) =>
      _rtdbSessionRef.child(projectId).remove();
  Future<void> clearAllSessions() => _rtdbSessionRef.remove();
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
  Stream<String?> liveFileContent(String projectId, String fileId) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .child('content')
        .onValue
        .map((event) => event.snapshot.value as String?);
  }

  Future<void> updateLiveFileContent(
      String projectId, String fileId, String content) =>
      _rtdbSessionRef
          .child(projectId)
          .child('files')
          .child(fileId)
          .child('content')
          .set(content);

  Future<void> addFileToSession(String projectId, MyFile file) => _rtdbSessionRef
      .child(projectId)
      .child('files')
      .child(file.fileId)
      .set({'name': file.name, 'content': file.content});

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

  Future<void> renameFileInSession(
      String projectId, String fileId, String newName) =>
      _rtdbSessionRef
          .child(projectId)
          .child('files')
          .child(fileId)
          .update({'name': newName});


  // ==========================================================
  // NUOVI METODI PER LA SESSIONE DI DEBUG
  // ==========================================================

  /// Aggiunge lo stato di debug alla sessione di lavoro esistente.
  Future<void> initializeDebugSession(String projectId, Map<String, dynamic> initialVariables) {
    // Scrive su .../sessions/{uid}/{projectId}/debugState
    return _rtdbSessionRef.child(projectId).child('debugState').set({
      'variables': initialVariables,
      'startedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Aggiorna le variabili nello stato di debug della sessione corrente.
  Future<void> updateDebugVariables(String projectId, Map<String, dynamic> newValues) {
    // Aggiorna .../sessions/{uid}/{projectId}/debugState/variables
    return _rtdbSessionRef.child(projectId).child('debugState').child('variables').update(newValues);
  }

  /// Ascolta le modifiche nel nodo delle variabili di debug della sessione corrente.
  Stream<Map<String, dynamic>> watchDebugVariables(String projectId) {
    // Ascolta .../sessions/{uid}/{projectId}/debugState/variables
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

  /// Rimuove lo stato di debug dalla sessione corrente, lasciando il resto intatto.
  Future<void> clearDebugSession(String projectId) {
    // Rimuove .../sessions/{uid}/{projectId}/debugState
    return _rtdbSessionRef.child(projectId).child('debugState').remove();
  }
}
// lib/data/repositories/rtdb_session_service.dart

import 'package:file_repository/file_repository.dart';
import 'package:firebase_database/firebase_database.dart';

/// Servizio dedicato alla gestione della sessione di lavoro "live"
/// su Firebase Realtime Database (RTDB).
class RtdbSessionService {
  final String uid;
  late final DatabaseReference _rtdbSessionRef;

  RtdbSessionService({required this.uid})
      : _rtdbSessionRef = FirebaseDatabase.instance.ref('sessions/$uid');

  // --- Gestione Sessione Generale ---

  Future<DataSnapshot> getSessionSnapshot() => _rtdbSessionRef.get();

  Future<void> removeProjectSession(String projectId) =>
      _rtdbSessionRef.child(projectId).remove();

  Future<void> clearAllSessions() => _rtdbSessionRef.remove();

  Future<void> startSession(
      String projectId, Map<String, dynamic> filesData) async {
    await clearAllSessions(); // Assicura che non ci siano altre sessioni attive
    final projectSessionRef = _rtdbSessionRef.child(projectId);
    await projectSessionRef.set({
      'sessionTimestamp': DateTime.now().toIso8601String(),
      'files': filesData,
    });
  }

  // --- Gestione File nella Sessione Live ---

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
      String projectId, String fileId, String content) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .child('content')
        .set(content);
  }

  Future<void> addFileToSession(String projectId, MyFile file) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(file.fileId)
        .set({'name': file.name, 'content': file.content ?? ''});
  }

  Future<void> removeFileFromSession(String projectId, String fileId) async {
    final fileNode = _rtdbSessionRef.child(projectId).child('files').child(fileId);
    final sessionFilesSnapshot = await _rtdbSessionRef.child(projectId).child('files').get();

    if (sessionFilesSnapshot.exists && (sessionFilesSnapshot.value as Map).length > 1) {
      await fileNode.remove();
    } else {
      await removeProjectSession(projectId);
    }
  }

  Future<void> renameFileInSession(
      String projectId, String fileId, String newName) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .update({'name': newName});
  }
}
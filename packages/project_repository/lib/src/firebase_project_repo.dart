import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:project_repository/src/services/firestore_storage_service.dart';
import 'package:project_repository/src/services/rtdb_session_service.dart';

/// Implementazione del ProjectRepository che coordina i servizi di storage
/// (Firestore) e di sessione live (RTDB).
class FirebaseProjectRepo implements ProjectRepo {
  final String uid;
  final FirestoreStorageService _storage;
  final RtdbSessionService _session;

  FirebaseProjectRepo({required this.uid})
      : _storage = FirestoreStorageService(uid: uid),
        _session = RtdbSessionService(uid: uid);

  // --- Logica di Recupero e Sincronizzazione ---

  @override
  Future<PendingSessionInfo?> checkForPendingSessions() async {
    final sessionSnapshot = await _session.getSessionSnapshot();
    if (!sessionSnapshot.exists || sessionSnapshot.value == null) return null;

    final sessionData = sessionSnapshot.value as Map<dynamic, dynamic>;
    if (sessionData.keys.isEmpty) {
      await _session.clearAllSessions();
      return null;
    }

    final projectId = sessionData.keys.first as String;
    final projectSession = sessionData[projectId] as Map<dynamic, dynamic>;
    final rtdbFiles = projectSession['files'] as Map<dynamic, dynamic>? ?? {};

    final firestoreDoc = await _storage.getProjectDoc(projectId);
    if (!firestoreDoc.exists) {
      await _session.removeProjectSession(projectId);
      return null;
    }

    final firestoreTimestamp = (firestoreDoc.data()!['updatedAt'] as Timestamp).toDate();
    final sessionTimestamp = DateTime.parse(projectSession['sessionTimestamp']);

    if (sessionTimestamp.isAfter(firestoreTimestamp)) {
      final structuralChanges = <UnsavedFileChange>[];
      final nonStructuralChanges = <String, String>{};

      final firestoreFiles = await _storage.getProjectFilesAsMap(projectId: projectId);

      for (var fileId in rtdbFiles.keys) {
        final rtdbFile = rtdbFiles[fileId] as Map<dynamic, dynamic>;
        final firestoreFile = firestoreFiles[fileId];

        if (firestoreFile != null) {
          final rtdbContent = rtdbFile['content'] as String;
          final firestoreContent = firestoreFile['content'] as String;

          if (rtdbContent != firestoreContent) {
            if (_haveStructuralDifferences(rtdbContent, firestoreContent)) {
              structuralChanges.add(UnsavedFileChange(
                fileId: fileId,
                fileName: rtdbFile['name'] as String,
                firestoreContent: firestoreContent,
                rtdbContent: rtdbContent,
              ));
            } else {
              nonStructuralChanges[fileId] = rtdbContent;
            }
          }
        }
      }

      if (nonStructuralChanges.isNotEmpty) {
        await _storage.syncFiles(projectId, nonStructuralChanges);
        for (final fileId in nonStructuralChanges.keys) {
          await _session.removeFileFromSession(projectId, fileId);
        }
      }

      if (structuralChanges.isNotEmpty) {
        return PendingSessionInfo(
          projectId: projectId,
          projectName: firestoreDoc.data()!['name'],
          changedFiles: structuralChanges,
        );
      }
    }

    await _session.removeProjectSession(projectId);
    return null;
  }

  bool _haveStructuralDifferences(String rtdbContent, String firestoreContent) {
    try {
      final rtdbData = jsonDecode(rtdbContent);
      final firestoreData = jsonDecode(firestoreContent);

      final List<dynamic> rtdbShapes = rtdbData['shapes'] ?? [];
      final List<dynamic> firestoreShapes = firestoreData['shapes'] ?? [];

      if (rtdbShapes.length != firestoreShapes.length) return true;

      final rtdbFingerprints = rtdbShapes.map((s) => '${s['id']}:${s['type']}').toSet();
      final firestoreFingerprints = firestoreShapes.map((s) => '${s['id']}:${s['type']}').toSet();

      return !rtdbFingerprints.containsAll(firestoreFingerprints);
    } catch (e) {
      return true;
    }
  }

  @override
  Future<void> recoverSession(String projectId) async {
    final sessionSnapshot = await _session.getSessionSnapshot();
    if (!sessionSnapshot.exists) return;

    final sessionData = (sessionSnapshot.value as Map<dynamic, dynamic>)[projectId];
    if (sessionData?['files'] is Map<dynamic, dynamic>) {
      final filesToSync = Map<String, String>.fromEntries(
        (sessionData['files'] as Map<dynamic, dynamic>).entries.map(
              (e) => MapEntry(e.key.toString(), e.value['content'].toString()),
        ),
      );
      await _storage.syncFiles(projectId, filesToSync);
    }
    await _session.removeProjectSession(projectId);
  }

  @override
  Future<void> discardSession(String projectId) => _session.removeProjectSession(projectId);

  @override
  Future<void> startWorkspaceSession(MyProject project) async {
    final files = await _storage.getProjectFiles(projectId: project.projectId);
    final filesData = {
      for (var file in files) file.fileId: {'name': file.name, 'content': file.content}
    };
    await _session.startSession(project.projectId, filesData);
  }

  @override
  Future<void> endWorkspaceSession(String projectId) => recoverSession(projectId);

  @override
  Future<void> recoverSingleFile({required String projectId, required String fileId, required String rtdbContent}) async {
    await _storage.updateFileContent(projectId: projectId, fileId: fileId, content: rtdbContent);
    await _session.removeFileFromSession(projectId, fileId);
  }

  @override
  Future<void> discardSingleFileChange({required String projectId, required String fileId}) {
    return _session.removeFileFromSession(projectId, fileId);
  }

  // Progetti (da Firestore)
  @override
  Stream<List<MyProject>> projects() => _storage.projects();

  @override
  Future<MyProject> createProject({required String name}) => _storage.createProject(name: name);

  @override
  Future<void> deleteProject({required String projectId}) async {
    // Operazione coordinata: prima rimuove la sessione, poi il progetto.
    await _session.removeProjectSession(projectId);
    await _storage.deleteProject(projectId: projectId);
  }

  @override
  Future<void> renameProject({required String projectId, required String newName}) =>
      _storage.renameProject(projectId: projectId, newName: newName);

  // File (CRUD Intelligente)
  @override
  Future<List<MyFile>> getProjectFiles({required String projectId}) =>
      _storage.getProjectFiles(projectId: projectId);

  @override
  Future<MyFile> addFileToProject({required String projectId, required String fileName, required String content}) async {
    final newFile = await _storage.addFileToProject(
      projectId: projectId,
      fileName: fileName,
      content: content,
    );
    await _session.addFileToSession(projectId, newFile);
    return newFile;
  }

  @override
  Future<void> deleteFile({required String projectId, required String fileId}) async {
    await _session.removeFileFromSession(projectId, fileId);
    await _storage.deleteFile(projectId: projectId, fileId: fileId);
  }

  @override
  Future<void> renameFile({required String projectId, required String fileId, required String newName}) async {
    await _storage.renameFile(projectId: projectId, fileId: fileId, newName: newName);
    await _session.renameFileInSession(projectId, fileId, newName);
  }

  // Sessione Live (da RTDB)
  @override
  Stream<String?> liveFileContent(String projectId, String fileId) =>
      _session.liveFileContent(projectId, fileId);

  @override
  Future<void> updateLiveFileContent(String projectId, String fileId, String content) =>
      _session.updateLiveFileContent(projectId, fileId, content);
}
import 'dart:convert';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:project_repository/src/services/firestore_storage_service.dart';
import 'package:project_repository/src/services/rtdb_session_service.dart';

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
    try {
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

      // Confronta sempre i contenuti RTDB vs Firestore, indipendentemente dai timestamp
      final structuralChanges = <UnsavedFileChange>[];
      final nonStructuralChanges = <String, String>{};

      final firestoreFiles = await _storage.getProjectFilesAsMap(projectId: projectId);

      for (var fileId in rtdbFiles.keys) {
        final rtdbFile = rtdbFiles[fileId] as Map<dynamic, dynamic>;
        final firestoreFile = firestoreFiles[fileId];

        if (firestoreFile != null) {
          final rtdbContent = (rtdbFile['content'] ?? '').toString();
          final firestoreContent = (firestoreFile['content'] ?? '').toString();

          if (rtdbContent != firestoreContent) {
            if (_haveStructuralDifferences(rtdbContent, firestoreContent)) {
              structuralChanges.add(UnsavedFileChange(
                fileId: fileId,
                fileName: (firestoreFile['name'] ?? 'File Sconosciuto').toString(),
                firestoreContent: firestoreContent,
                rtdbContent: rtdbContent,
              ));
            } else {
              nonStructuralChanges[fileId] = rtdbContent;
            }
          }
        }
      }

      // Sincronizza subito le differenze non strutturali, come prima
      if (nonStructuralChanges.isNotEmpty) {
        await _storage.syncFiles(projectId, nonStructuralChanges);
        for (final fileId in nonStructuralChanges.keys) {
          await _session.removeFileFromSession(projectId, fileId);
        }
      }

      // Se rimangono differenze strutturali, restituisci info per il recupero manuale
      if (structuralChanges.isNotEmpty) {
        return PendingSessionInfo(
          projectId: projectId,
          projectName: firestoreDoc.data()!['name'],
          changedFiles: structuralChanges,
        );
      }

      // Nessuna differenza significativa: pulisci la sessione
      await _session.removeProjectSession(projectId);
      return null;
    } catch (e) {
      // Soft-fail: non bloccare il caricamento dei progetti per transient errors
      // (es. mismatch temporaneo RTDB/Firestore, rete, token scaduto ma recuperabile).
      return null;
    }
  }

  bool _haveStructuralDifferences(String rtdbContent, String firestoreContent) {
    try {
      final rtdbData = jsonDecode(rtdbContent);
      final firestoreData = jsonDecode(firestoreContent);

      final List<dynamic> rtdbNodes = rtdbData['nodes'] ?? [];
      final List<dynamic> firestoreNodes = firestoreData['nodes'] ?? [];

      if (rtdbNodes.length != firestoreNodes.length) return true;

      final rtdbFingerprints = rtdbNodes.map((n) => '${n['id']}:${n['kind']}').toSet();
      final firestoreFingerprints = firestoreNodes.map((n) => '${n['id']}:${n['kind']}').toSet();

      return !rtdbFingerprints.containsAll(firestoreFingerprints);
    } catch (e) {
      return true;
    }
  }

  @override
  Future<void> recoverSession(String projectId) async {
    try {
      final sessionSnapshot = await _session.getSessionSnapshot();
      if (!sessionSnapshot.exists) return;

      final sessionData = (sessionSnapshot.value as Map<dynamic, dynamic>)[projectId];
      if (sessionData?['files'] is Map<dynamic, dynamic>) {
        // Carica i file esistenti su Firestore in una mappa {fileId: docData}
        final firestoreFilesMap = await _storage.getProjectFilesAsMap(projectId: projectId);

        final Map<String, String> filesToSync = {};
        final Map<String, dynamic> filesSession = Map<String, dynamic>.from(sessionData['files'] as Map);

        for (final entry in filesSession.entries) {
          final fileId = entry.key.toString();
          final fileNode = Map<String, dynamic>.from(entry.value as Map);
          final rtdbContent = (fileNode['content'] ?? '').toString();

          if (rtdbContent.trim().isEmpty) {
            await _session.removeFileFromSession(projectId, fileId);
            continue;
          }

          try {
            // Parse JSON RTDB
            final rtdbJson = jsonDecode(rtdbContent) as Map<String, dynamic>;
            final rtdbFlowchartId = (rtdbJson['flowchartId'] ?? '').toString();

            // Documento Firestore per lo stesso fileId
            final firestoreFileDoc = firestoreFilesMap[fileId];
            if (firestoreFileDoc == null) {
              // File rimosso su Firestore: pulisci la sessione
              await _session.removeFileFromSession(projectId, fileId);
              continue;
            }

            final firestoreContent = (firestoreFileDoc['content'] ?? '').toString();
            String firestoreFlowchartId = '';
            if (firestoreContent.trim().isNotEmpty) {
              try {
                final fsJson = jsonDecode(firestoreContent) as Map<String, dynamic>;
                firestoreFlowchartId = (fsJson['flowchartId'] ?? '').toString();
              } catch (_) {
                // Contenuto non parseabile: per sicurezza evita overwrite
                await _session.removeFileFromSession(projectId, fileId);
                continue;
              }
            }

            // ✅ Sincronizza solo se lo stesso flowchart sta aggiornando se stesso
            if (rtdbFlowchartId.isNotEmpty &&
                (firestoreFlowchartId.isEmpty || rtdbFlowchartId == firestoreFlowchartId)) {
              filesToSync[fileId] = rtdbContent;
            } else {
              // Mismatch: non sincronizzare per evitare scambio di contenuti
              await _session.removeFileFromSession(projectId, fileId);
            }
          } catch (_) {
            // JSON RTDB non valido: ignora ed elimina dalla sessione
            await _session.removeFileFromSession(projectId, fileId);
          }
        }

        if (filesToSync.isNotEmpty) {
          await _storage.syncFiles(projectId, filesToSync);
        }
      }
    } catch (e) {
      // Soft-fail: se qualcosa va storto qui, non propagare in alto.
      return;
    }
    // Aggiorna sempre l'ultimo accesso quando l'utente gestisce la sessione in rientro
    await _storage.updateProjectAccessTime(projectId).catchError((_) {});
    return;
  }

  // --- Gestione File (CRUD Intelligente) ---

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

  @override
  Stream<String?> liveFileContent(String projectId, String fileId) =>
      _session.liveFileContent(projectId, fileId);

  @override
  Future<void> updateLiveFileContent(String projectId, String fileId, String content) =>
      _session.updateLiveFileContent(projectId, fileId, content);

  // --- CONDIVISIONE PROGETTI ---

  @override
  Future<void> updateProjectVisibility({required String projectId, required bool isPublic}) {
    return _storage.updateProjectVisibility(projectId: projectId, isPublic: isPublic);
  }

  @override
  Future<MyProject?> getPublicProjectById(String projectId) async {
    return _storage.getPublicProjectById(projectId);
  }

  @override
  Future<Map<String, dynamic>?> getPublicProjectWithFiles(String projectId) {
    return _storage.getPublicProjectWithFiles(projectId);
  }

  // --- Gestione Progetti (CRUD) ---

  @override
  Stream<List<MyProject>> projects() => _storage.projects();

  @override
  Future<MyProject> createProject({required String name}) => _storage.createProject(name: name);

  @override
  Future<void> deleteProject({required String projectId}) async {
    await _storage.deleteProject(projectId: projectId);
    await _session.removeProjectSession(projectId);
  }

  @override
  Future<void> renameProject({required String projectId, required String newName}) =>
      _storage.renameProject(projectId: projectId, newName: newName);

  // --- Gestione File (lista e aggiunta) ---

  @override
  Future<List<MyFile>> getProjectFiles({required String projectId}) async {
    // 1. Carica i file da Firestore (base persistente)
    final firestoreFiles = await _storage.getProjectFiles(projectId: projectId);

    try {
      // 2. Controlla se esiste una sessione attiva su RTDB
      final sessionSnapshot = await _session.getSessionSnapshot();
      if (sessionSnapshot.exists && sessionSnapshot.value != null) {
        final allSessions = sessionSnapshot.value as Map<dynamic, dynamic>;
        final projectSession = allSessions[projectId];

        if (projectSession != null && projectSession['files'] != null) {
          final sessionFilesMap = Map<dynamic, dynamic>.from(projectSession['files']);

          // 3. Fai il merge: se un file è in sessione, usa il contenuto RTDB
          final mergedFiles = firestoreFiles.map((fsFile) {
            final rtdbFile = sessionFilesMap[fsFile.fileId];
            if (rtdbFile != null) {
              final rtdbContent = rtdbFile['content']?.toString();
              if (rtdbContent != null && rtdbContent.isNotEmpty) {
                // Usa il contenuto live della sessione
                return fsFile.copyWith(content: rtdbContent);
              }
            }
            return fsFile;
          }).toList();

          return mergedFiles;
        }
      }
    } catch (e) {
      // Se RTDB fallisce, ritorna almeno i file Firestore
      print('⚠️ Errore merge RTDB in getProjectFiles: $e');
    }

    return firestoreFiles;
  }

  @override
  Future<MyFile> addFileToProject({
    required String projectId,
    required String fileName,
    required String content,
  }) async {
    final newFile = await _storage.addFileToProject(
      projectId: projectId,
      fileName: fileName,
      content: content,
    );
    await _session.addFileToSession(projectId, newFile);
    return newFile;
  }

  // --- Sessione Workspace (RTDB) ---

  @override
  Future<void> startWorkspaceSession(MyProject project) async {
    // Avvia una nuova sessione pulita per il progetto con nessun file in coda
    await _session.startSession(project.projectId, {});
  }

  @override
  Future<void> endWorkspaceSession(String projectId) async {
    // 1) Prova a sincronizzare i file RTDB -> Firestore prima di chiudere
    bool syncOk = true;
    try {
      final sessionSnapshot = await _session.getSessionSnapshot();
      if (sessionSnapshot.exists && sessionSnapshot.value is Map) {
        final Map<dynamic, dynamic> data = sessionSnapshot.value as Map;
        final projectNode = data[projectId];
        if (projectNode is Map && projectNode['files'] is Map) {
          final files = Map<String, dynamic>.from(projectNode['files'] as Map);
          final Map<String, String> filesToSync = {};
          for (final entry in files.entries) {
            final fileId = entry.key.toString();
            final node = Map<String, dynamic>.from(entry.value as Map);
            final content = (node['content'] ?? '').toString();
            if (content.trim().isEmpty) continue;
            // Valida JSON basico per evitare scritture corrotte
            try {
              jsonDecode(content);
              filesToSync[fileId] = content;
            } catch (_) {
              // Salta file non validi
            }
          }
          if (filesToSync.isNotEmpty) {
            await _storage.syncFiles(projectId, filesToSync);
          }
        }
      }
    } catch (_) {
      syncOk = false;
    }

    // 2) Aggiorna in ogni caso l'ultimo accesso
    await _storage.updateProjectAccessTime(projectId).catchError((_) {});

    // 3) Rimuovi la sessione solo se la sincronizzazione non è fallita in modo critico
    if (syncOk) {
      await _session.removeProjectSession(projectId).catchError((_) {});
    }
  }

  @override
  Future<void> discardSession(String projectId) async {
    await _session.removeProjectSession(projectId);
    // Anche in caso di rifiuto dei cambi, aggiorna updatedAt
    await _storage.updateProjectAccessTime(projectId).catchError((_) {});
  }

  @override
  Future<void> recoverSingleFile({
    required String projectId,
    required String fileId,
    required String rtdbContent,
  }) async {
    await _storage.updateFileContent(projectId: projectId, fileId: fileId, content: rtdbContent);
    await _session.removeFileFromSession(projectId, fileId);
  }

  @override
  Future<void> discardSingleFileChange({required String projectId, required String fileId}) async {
    await _session.removeFileFromSession(projectId, fileId);
  }

  @override
  Future<void> saveSessionToFirestore(String projectId) async {
    try {
      final sessionSnapshot = await _session.getSessionSnapshot();
      if (!sessionSnapshot.exists || sessionSnapshot.value == null) return;

      final allSessions = sessionSnapshot.value as Map<dynamic, dynamic>;
      final projectSession = allSessions[projectId];
      
      if (projectSession != null && projectSession['files'] is Map<dynamic, dynamic>) {
        final filesMap = Map<String, dynamic>.from(projectSession['files'] as Map);
        final Map<String, String> filesToSync = {};

        for (final entry in filesMap.entries) {
          final fileId = entry.key.toString();
          final fileData = Map<String, dynamic>.from(entry.value as Map);
          final content = (fileData['content'] ?? '').toString();
          
          // Sincronizza solo se c'è contenuto
          if (content.trim().isNotEmpty) {
             filesToSync[fileId] = content;
          }
        }

        if (filesToSync.isNotEmpty) {
          await _storage.syncFiles(projectId, filesToSync);
        }
      }
    } catch (e) {
      // Logga errore ma non bloccare, è una best-effort sync
      print('⚠️ Errore durante saveSessionToFirestore: $e');
    }
  }

  // --- Gestione File (CRUD Intelligente) ---
}

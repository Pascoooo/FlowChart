import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
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

  /// **METODO CHIAVE AGGIORNATO**
  /// Controlla se ci sono differenze strutturali (aggiunta/rimozione di nodi)
  /// tra due versioni JSON di un flowchart, usando il nuovo modello dati.
  bool _haveStructuralDifferences(String rtdbContent, String firestoreContent) {
    try {
      final rtdbData = jsonDecode(rtdbContent);
      final firestoreData = jsonDecode(firestoreContent);

      // Legge la lista di 'nodes' invece di 'shapes'.
      final List<dynamic> rtdbNodes = rtdbData['nodes'] ?? [];
      final List<dynamic> firestoreNodes = firestoreData['nodes'] ?? [];

      if (rtdbNodes.length != firestoreNodes.length) return true;

      // Crea un "fingerprint" per ogni nodo basato su ID e 'kind'.
      final rtdbFingerprints = rtdbNodes.map((n) => '${n['id']}:${n['kind']}').toSet();
      final firestoreFingerprints = firestoreNodes.map((n) => '${n['id']}:${n['kind']}').toSet();

      // Se i set di fingerprint non sono identici, la struttura è cambiata.
      return !rtdbFingerprints.containsAll(firestoreFingerprints);
    } catch (e) {
      // Se il parsing fallisce, considerala una differenza strutturale per sicurezza.
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

  @override
  Stream<List<MyProject>> projects() => _storage.projects();

  @override
  Future<MyProject> createProject({required String name}) => _storage.createProject(name: name);

  @override
  Future<void> deleteProject({required String projectId}) async {
    await _session.removeProjectSession(projectId);
    await _storage.deleteProject(projectId: projectId);
  }

  @override
  Future<void> renameProject({required String projectId, required String newName}) =>
      _storage.renameProject(projectId: projectId, newName: newName);

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

  @override
  Stream<String?> liveFileContent(String projectId, String fileId) =>
      _session.liveFileContent(projectId, fileId);

  @override
  Future<void> updateLiveFileContent(String projectId, String fileId, String content) =>
      _session.updateLiveFileContent(projectId, fileId, content);

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

  @override
  Future<void> startDebugSession({required String projectId, required Flowchart flowchart}) async {
    // Avvia la sessione con tabella variabili vuota ma salva l'elenco delle variabili dichiarate
    final declared = <String, Map<String, dynamic>>{
      for (final v in flowchart.variables)
        v.name: {
          'dataType': v.dataType,
          'scope': v.scope.name,
        }
    };
    return _session.initializeDebugSession(projectId, {}, declaredVariables: declared);
  }


  @override
  Future<void> updateDebugVariables({required String projectId, required Map<String, dynamic> variables}) async {
    // Valida che ogni variabile esista tra quelle dichiarate e che il tipo sia compatibile
    final declared = await _session.getDeclaredVariables(projectId);

    for (final entry in variables.entries) {
      final name = entry.key;
      final value = entry.value;

      if (!declared.containsKey(name)) {
        throw StateError('Variabile "$name" non dichiarata nella workarea');
      }

      final dataType = (declared[name]!['dataType'] as String?)?.toLowerCase() ?? 'string';
      if (!_isTypeCompatible(dataType, value)) {
        throw StateError('Tipo non compatibile per "$name": atteso $dataType, trovato ${value.runtimeType}');
      }
    }

    await _session.updateDebugVariables(projectId, variables);
  }

  bool _isTypeCompatible(String dataType, dynamic value) {
    if (value == null) return true; // consenti null come placeholder
    switch (dataType) {
      case 'string':
        return value is String;
      case 'int':
      case 'integer':
        return value is int;
      case 'double':
      case 'number':
      case 'float':
        return value is num; // consente sia int sia double
      case 'bool':
      case 'boolean':
        return value is bool;
      default:
        return true; // tipi custom non sono strettamente verificabili qui
    }
  }

  @override
  Future<void> clearDebugVariables({required String projectId}) async {
    await _session.clearDebugSession(projectId);
  }

  @override
  Future<void> advanceDebugStep({required String projectId, required FlowNode? currentNode}) async {
    if (currentNode == null) return;

    // Non creare più placeholder per Input/Output/Assignment: la logica e gli errori
    // vengono gestiti nel DebugEngine. Qui non facciamo side-effect se non necessario.
    if (currentNode is InputNode) {
      return;
    } else if (currentNode is OutputNode) {
      return;
    } else if (currentNode is AssignmentNode) {
      return;
    } else if (currentNode is DecisionNode ||
        currentNode is WhileNode ||
        currentNode is DoWhileNode) {
      return;
    }

    // Nessun aggiornamento di default
    return;
  }


  @override
  Future<Map<String, dynamic>> getDebugVariables({required String projectId}) {
    return _session.getCurrentDebugVariables(projectId);
  }


  @override
  Future<void> endDebugSession({required String projectId}) async {
    await _session.clearDebugSession(projectId);
  }

  @override
  Stream<Map<String, dynamic>> watchDebugVariables({required String projectId}) {
    return _session.watchDebugVariables(projectId);
  }
}
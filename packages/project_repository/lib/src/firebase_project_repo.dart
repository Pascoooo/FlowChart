import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../project_repository.dart';


/// Contiene le informazioni su un singolo file con modifiche non salvate.
class UnsavedFileChange {
  final String fileId;
  final String fileName;
  final String firestoreContent;
  final String rtdbContent;

  UnsavedFileChange({
    required this.fileId,
    required this.fileName,
    required this.firestoreContent,
    required this.rtdbContent,
  });
}

/// Classe helper che contiene l'elenco di tutti i file con modifiche.
class PendingSessionInfo {
  final String projectId;
  final String projectName;
  final List<UnsavedFileChange> changedFiles;

  PendingSessionInfo({
    required this.projectId,
    required this.projectName,
    required this.changedFiles,
  });
}

class FirebaseProjectRepo implements ProjectRepo {
  final String uid;
  final CollectionReference<Map<String, dynamic>> projectCollection;
  final DatabaseReference _rtdbSessionRef;

  FirebaseProjectRepo({required this.uid})
      : projectCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('projects'),
        _rtdbSessionRef = FirebaseDatabase.instance.ref('sessions/$uid');

  @override
  Future<PendingSessionInfo?> checkForPendingSessions() async {
    final sessionSnapshot = await _rtdbSessionRef.get();
    if (!sessionSnapshot.exists || sessionSnapshot.value == null) return null;

    final sessionData = sessionSnapshot.value as Map<dynamic, dynamic>;
    if (sessionData.keys.isEmpty) {
      await _rtdbSessionRef.remove();
      return null;
    }

    final projectId = sessionData.keys.first as String;
    final projectSession = sessionData[projectId] as Map<dynamic, dynamic>;
    final rtdbFiles = projectSession['files'] as Map<dynamic, dynamic>? ?? {};

    final firestoreDoc = await projectCollection.doc(projectId).get();
    if (!firestoreDoc.exists) {
      await _rtdbSessionRef.child(projectId).remove();
      return null;
    }

    final firestoreTimestamp = (firestoreDoc.data()!['updatedAt'] as Timestamp).toDate();
    final sessionTimestamp = DateTime.parse(projectSession['sessionTimestamp']);

    if (sessionTimestamp.isAfter(firestoreTimestamp)) {
      final List<UnsavedFileChange> changedFiles = [];
      final firestoreFilesSnapshot = await projectCollection.doc(projectId).collection('files').get();
      final firestoreFiles = {for (var doc in firestoreFilesSnapshot.docs) doc.id: doc.data()};

      for (var fileId in rtdbFiles.keys) {
        final rtdbFile = rtdbFiles[fileId] as Map<dynamic, dynamic>;
        final firestoreFile = firestoreFiles[fileId];

        if (firestoreFile != null) {
          final rtdbContent = rtdbFile['content'] as String;
          final firestoreContent = firestoreFile['content'] as String;

          if (rtdbContent != firestoreContent) {
            changedFiles.add(UnsavedFileChange(
              fileId: fileId,
              fileName: rtdbFile['name'] as String,
              firestoreContent: firestoreContent,
              rtdbContent: rtdbContent,
            ));
          }
        }
      }

      if (changedFiles.isNotEmpty) {
        return PendingSessionInfo(
          projectId: projectId,
          projectName: firestoreDoc.data()!['name'],
          changedFiles: changedFiles,
        );
      }
    }

    await _rtdbSessionRef.child(projectId).remove();
    return null;
  }

  @override
  Future<void> recoverSession(String projectId) async {
    final sessionSnapshot = await _rtdbSessionRef.child(projectId).get();
    if (!sessionSnapshot.exists) return;

    final projectSession = sessionSnapshot.value as Map<dynamic, dynamic>;
    if (projectSession['files'] is Map<dynamic, dynamic>) {
      await _syncProjectToFirestore(projectId, projectSession['files']);
    }
    await _rtdbSessionRef.child(projectId).remove();
  }

  @override
  Future<void> discardSession(String projectId) async {
    await _rtdbSessionRef.child(projectId).remove();
  }

  @override
  Future<void> startWorkspaceSession(MyProject project) async {
    await _rtdbSessionRef.remove();

    final projectSessionRef = _rtdbSessionRef.child(project.projectId);
    final files = await getProjectFiles(projectId: project.projectId);

    // Prepara il banco di lavoro copiando i file dall'archivio
    final Map<String, dynamic> filesData = {
      for (var file in files) file.fileId: {'name': file.name, 'content': file.content}
    };

    await projectSessionRef.set({
      'sessionTimestamp': DateTime.now().toIso8601String(),
      'files': filesData,
    });
  }

  @override
  Future<void> endWorkspaceSession(String projectId) async {
    await recoverSession(projectId);
  }


  @override
  Future<void> addFileToSession(String projectId, MyFile file) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(file.fileId)
        .set({'name': file.name, 'content': file.content ?? ''});
  }

  @override
  Future<void> removeFileFromSession(String projectId, String fileId) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .remove();
  }

  @override
  Future<void> renameFileInSession(String projectId, String fileId, String newName) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .update({'name': newName});
  }


  @override
  Future<void> recoverSingleFile({required String projectId, required String fileId, required String rtdbContent}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .update({'content': rtdbContent});
    await _rtdbSessionRef.child(projectId).child('files').child(fileId).remove();
  }

  @override
  Future<void> discardSingleFileChange({required String projectId, required String fileId}) async {
    await _rtdbSessionRef.child(projectId).child('files').child(fileId).remove();
  }

  // --- Gestione Progetti (CRUD su Firestore) ---

  @override
  Stream<List<MyProject>> projects() {
    return projectCollection.snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
        MyProject.fromEntity(MyProjectEntity.fromDocument(doc.data()!)))
        .toList());
  }

  @override
  Future<MyProject> createProject({required String name}) async {
    final projectId = const Uuid().v4();
    final newProjectEntity = MyProjectEntity(
        projectId: projectId, name: name, updatedAt: DateTime.now());
    await projectCollection.doc(projectId).set(newProjectEntity.toDocument());
    return MyProject.fromEntity(newProjectEntity);
  }

  @override
  Future<void> deleteProject({required String projectId}) async {
    await _rtdbSessionRef.child(projectId).remove();
    final filesSnapshot =
    await projectCollection.doc(projectId).collection('files').get();
    for (var doc in filesSnapshot.docs) {
      await doc.reference.delete();
    }
    await projectCollection.doc(projectId).delete();
  }

  @override
  Future<void> renameProject(
      {required String projectId, required String newName}) async {
    await projectCollection.doc(projectId).update({'name': newName});
  }

  // --- Gestione File (CRUD su Firestore) ---

  @override
  Future<List<MyFile>> getProjectFiles({required String projectId}) async {
    final snapshot =
    await projectCollection.doc(projectId).collection('files').get();
    return snapshot.docs
        .map((doc) => MyFile.fromEntity(MyFileEntity.fromDocument(doc.data())))
        .toList();
  }

  @override
  Future<MyFile> addFileToProject(
      {required String projectId,
        required String fileName,
        required String content}) async {
    final fileId = const Uuid().v4();
    final newFileEntity =
    MyFileEntity(fileId: fileId, name: fileName, content: content);
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .set(newFileEntity.toDocument());
    return MyFile.fromEntity(newFileEntity);
  }

  @override
  Future<void> deleteFile(
      {required String projectId, required String fileId}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

  @override
  Future<void> renameFile(
      {required String projectId,
        required String fileId,
        required String newName}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .update({'name': newName});
  }

  // --- Gestione Realtime (Lavoro sul "banco di lavoro") ---

  @override
  Stream<String?> liveFileContent(String projectId, String fileId) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .child('content')
        .onValue
        .map((event) => event.snapshot.value as String?);
  }

  @override
  Future<void> updateLiveFileContent(
      String projectId, String fileId, String content) {
    return _rtdbSessionRef
        .child(projectId)
        .child('files')
        .child(fileId)
        .child('content')
        .set(content);
  }

  /// Metodo privato per sincronizzare i dati da RTDB a Firestore.
  Future<void> _syncProjectToFirestore(
      String projectId, Map<dynamic, dynamic> filesData) async {
    final batch = FirebaseFirestore.instance.batch();
    final filesRef = projectCollection.doc(projectId).collection('files');

    for (var fileId in filesData.keys) {
      final fileData = filesData[fileId];
      if (fileData is Map<dynamic, dynamic> &&
          fileData.containsKey('content')) {
        final docRef = filesRef.doc(fileId);
        batch.update(docRef, {'content': fileData['content']});
      }
    }
    batch.update(
        projectCollection.doc(projectId), {'updatedAt': DateTime.now()});
    await batch.commit();
  }
}
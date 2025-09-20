import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:uuid/uuid.dart';

/// Servizio dedicato a tutte le operazioni CRUD (Create, Read, Update, Delete)
/// sullo storage permanente in Cloud Firestore.
class FirestoreStorageService {
  final String uid;
  late final CollectionReference<Map<String, dynamic>> projectCollection;

  FirestoreStorageService({required this.uid})
      : projectCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('projects');

  // --- Gestione Progetti ---

  Stream<List<MyProject>> projects() {
    return projectCollection.snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
        MyProject.fromEntity(MyProjectEntity.fromDocument(doc.data()!)))
        .toList());
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProjectDoc(String projectId) {
    return projectCollection.doc(projectId).get();
  }

  Future<MyProject> createProject({required String name}) async {
    final projectId = const Uuid().v4();
    final newProjectEntity = MyProjectEntity(
        projectId: projectId, name: name, updatedAt: DateTime.now());
    await projectCollection.doc(projectId).set(newProjectEntity.toDocument());
    return MyProject.fromEntity(newProjectEntity);
  }

  Future<void> deleteProject({required String projectId}) async {
    final filesSnapshot =
    await projectCollection.doc(projectId).collection('files').get();
    for (var doc in filesSnapshot.docs) {
      await doc.reference.delete();
    }
    await projectCollection.doc(projectId).delete();
  }

  Future<void> renameProject(
      {required String projectId, required String newName}) async {
    await projectCollection.doc(projectId).update({'name': newName});
  }

  // --- Gestione File ---

  Future<List<MyFile>> getProjectFiles({required String projectId}) async {
    final snapshot =
    await projectCollection.doc(projectId).collection('files').get();
    return snapshot.docs
        .map((doc) => MyFile.fromEntity(MyFileEntity.fromDocument(doc.data())))
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> getProjectFilesAsMap({required String projectId}) async {
    final snapshot = await projectCollection.doc(projectId).collection('files').get();
    return {for (var doc in snapshot.docs) doc.id: doc.data()};
  }

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

  Future<void> deleteFile(
      {required String projectId, required String fileId}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

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

  /// Sincronizza su Firestore un set di file tramite un'operazione batch.
  Future<void> syncFiles(
      String projectId, Map<String, String> filesToSync) async {
    final batch = FirebaseFirestore.instance.batch();
    final filesRef = projectCollection.doc(projectId).collection('files');

    for (var entry in filesToSync.entries) {
      final fileId = entry.key;
      final content = entry.value;
      final docRef = filesRef.doc(fileId);
      batch.update(docRef, {'content': content});
    }

    batch.update(projectCollection.doc(projectId), {'updatedAt': DateTime.now()});
    await batch.commit();
  }

  Future<void> updateFileContent(
      {required String projectId,
        required String fileId,
        required String content}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .update({'content': content});
  }
}
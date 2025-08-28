import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:uuid/uuid.dart';
import '../project_repository.dart';

class FirebaseProjectRepo implements ProjectRepo {
  final String uid;
  final CollectionReference<Map<String, dynamic>> projectCollection;

  FirebaseProjectRepo({required this.uid})
      : projectCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('projects');

  @override
  Future<List<MyProject>> getProjects() async {
    try {
      final snapshot = await projectCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final entity = MyProjectEntity.fromDocument(data);
        return MyProject.fromEntity(entity);
      }).toList();
    } catch (e) {
      log('Errore nel recupero dei progetti: $e');
      rethrow;
    }
  }

  @override
  Future<void> createProject({required String name}) async {
    try {
      final projectId = const Uuid().v4();
      final newProject = MyProjectEntity(
        projectId: projectId,
        name: name,
      );
      await projectCollection.doc(projectId).set(newProject.toDocument());
    } catch (e) {
      log('Errore nella creazione del progetto: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteProject({required String projectId}) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final filesCollection = projectCollection.doc(projectId).collection('files');
      final filesSnapshot = await filesCollection.get();

      for (final doc in filesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(projectCollection.doc(projectId));
      await batch.commit();
    } catch (e) {
      log('Errore nell\'eliminazione del progetto e dei suoi file: $e');
      rethrow;
    }
  }

  @override
  Future<void> renameProject({required String projectId, required String newName}) async {
    try {
      await projectCollection.doc(projectId).update({'name': newName});
    } catch (e) {
      log('Errore nella ridenominazione del progetto: $e');
      rethrow;
    }
  }

  @override
  Future<List<MyFile>> getProjectFiles({required String projectId}) async {
    try {
      final filesCollection = projectCollection.doc(projectId).collection('files');
      final snapshot = await filesCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final entity = MyFileEntity.fromDocument(data);
        return MyFile.fromEntity(entity);
      }).toList();
    } catch (e) {
      log('Errore nel recupero dei file del progetto: $e');
      rethrow;
    }
  }

  // Metodo per creare un file, ora con projectId
  @override
  Future<void> addFileToProject({
    required String projectId,
    required String fileName,
    required String content,
  }) async {
    try {
      final fileId = const Uuid().v4();
      final newFile = MyFileEntity(
        fileId: fileId,
        name: fileName,
        content: content,
      );
      await projectCollection.doc(projectId).collection('files').doc(fileId).set(newFile.toDocument());
    } catch (e) {
      log('Errore nell\'aggiunta del file al progetto: $e');
      rethrow;
    }
  }

  // Metodo per eliminare un file, ora con projectId
  @override
  Future<void> deleteFile({required String projectId, required String fileId}) async {
    try {
      await projectCollection.doc(projectId).collection('files').doc(fileId).delete();
    } catch (e) {
      log('Errore nell\'eliminazione del file: $e');
      rethrow;
    }
  }

  // Metodo per rinominare un file, ora con projectId
  @override
  Future<void> renameFile({
    required String projectId,
    required String fileId,
    required String newName,
  }) async {
    try {
      await projectCollection.doc(projectId).collection('files').doc(fileId).update({'name': newName});
    } catch (e) {
      log('Errore nella ridenominazione del file: $e');
      rethrow;
    }
  }

  // Metodo per aggiornare il contenuto del file, ora con projectId
  @override
  Future<void> updateFileContent({
    required String projectId,
    required String fileId,
    required String newContent,
  }) async {
    try {
      await projectCollection.doc(projectId).collection('files').doc(fileId).update({'content': newContent});
    } catch (e) {
      log('Errore nell\'aggiornamento del contenuto del file: $e');
      rethrow;
    }
  }
}
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:file_repository/file_repository.dart';
import 'package:uuid/uuid.dart';
import '../project_repository.dart';

class FirebaseProjectRepo implements ProjectRepo {
  final String uid;
  final CollectionReference<Map<String, dynamic>> projectCollection;
  final DatabaseReference rtdbLogRef;

  FirebaseProjectRepo({required this.uid})
      : projectCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('projects'),
      rtdbLogRef = FirebaseDatabase.instance.ref('users/$uid/projectslog');


  @override
  Stream<List<MyProject>> projects() {
    return projectCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return MyProject.fromEntity(MyProjectEntity.fromDocument(doc.data()));
      }).toList();
    });
  }


  @override
  Future<Map<String, DateTime>> getUserTimestamps() async {
    try {
      final snapshot = await rtdbLogRef.get();
      if (!snapshot.exists || snapshot.value == null) return {};

      final data = snapshot.value as Map<dynamic, dynamic>;
      return data.map((key, value) => MapEntry(key.toString(), DateTime.parse(value as String)));
    } catch (e) {
      log('Errore nel caricamento dei timestamp da RTDB: $e');
      return {};
    }
  }


  @override
  Future<void> saveUserTimestamps(Map<String, DateTime> timestamps) {
    try {
      final serializableData = timestamps.map((key, value) => MapEntry(key, value.toIso8601String()));
      return rtdbLogRef.set(serializableData);
    } catch (e) {
      log('Errore nel salvataggio dei timestamp su RTDB: $e');
      rethrow;
    }
  }

  @override
  Future<MyProject> createProject({required String name}) async {
    try {
      final projectId = const Uuid().v4();
      final newProjectEntity = MyProjectEntity(
        projectId: projectId,
        name: name,
        updatedAt: DateTime.now(),
      );
      await projectCollection.doc(projectId).set(newProjectEntity.toDocument());
      return MyProject.fromEntity(newProjectEntity);
    } catch (e) {
      log('Errore nella creazione del progetto: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteProject({required String projectId}) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final filesCollection =
      projectCollection.doc(projectId).collection('files');
      final filesSnapshot = await filesCollection.get();
      for (final doc in filesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(projectCollection.doc(projectId));
      await batch.commit();

      await rtdbLogRef.child(projectId).remove();

    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> renameProject(
      {required String projectId, required String newName}) async {
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
      final filesCollection =
      projectCollection.doc(projectId).collection('files');
      final snapshot = await filesCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final entity = MyFileEntity.fromDocument(data);
        return MyFile.fromEntity(entity);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

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
      await projectCollection
          .doc(projectId)
          .collection('files')
          .doc(fileId)
          .set(newFile.toDocument());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(
      {required String projectId, required String fileId}) async {
    try {
      await projectCollection
          .doc(projectId)
          .collection('files')
          .doc(fileId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> renameFile({
    required String projectId,
    required String fileId,
    required String newName,
  }) async {
    try {
      await projectCollection
          .doc(projectId)
          .collection('files')
          .doc(fileId)
          .update({'name': newName});
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateFileContent({
    required String projectId,
    required String fileId,
    required String newContent,
  }) async {
    try {
      await projectCollection
          .doc(projectId)
          .collection('files')
          .doc(fileId)
          .update({'content': newContent});
    } catch (e) {
      rethrow;
    }
  }
}
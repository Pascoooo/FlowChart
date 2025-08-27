// dart
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../file_repository.dart';

class FirebaseFileRepo implements FileRepo {
  final String uid;
  final CollectionReference<Map<String, dynamic>> projectCollection;

  FirebaseFileRepo({required this.uid})
      : projectCollection =
  FirebaseFirestore.instance.collection("/projects/$uid/files");

  @override
  Future<List<MyFile>> getFiles() async {
    try {
      final snapshot = await projectCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final entity = MyFileEntity.fromDocument(data);
        return MyFile.fromEntity(entity);
      }).toList();
    } catch (e) {
      log('Errore nel recupero dei file: $e');
      rethrow;
    }
  }

  @override
  Future<void> createFile({required String name}) async {
    try {
      final fileId = const Uuid().v4();
      final newFile = MyFileEntity(
        fileId: fileId,
        name: name,
        content: '',
      );
      await projectCollection.doc(fileId).set(newFile.toDocument());
    } catch (e) {
      log('Errore nella creazione del file: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFile({required String fileId}) async {
    try {
      await projectCollection.doc(fileId).delete();
    } catch (e) {
      log('Errore nell\'eliminazione del file: $e');
      rethrow;
    }
  }

  @override
  Future<void> renameFile({required String fileId, required String newName}) async {
    try {
      await projectCollection.doc(fileId).update({'name': newName});
    } catch (e) {
      log('Errore nella ridenominazione del file: $e');
      rethrow;
    }
  }
}
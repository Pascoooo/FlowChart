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
    final now = DateTime.now();

    // Ora possiamo creare l'entità senza specificare `lastVisibilityChange`.
    // Il campo sarà nullo e `toDocument` non lo salverà nel database.
    final newProjectEntity = MyProjectEntity(
      projectId: projectId,
      name: name,
      updatedAt: now,
      isPublic: false,
      ownerId: uid,
    );
    await projectCollection.doc(projectId).set(newProjectEntity.toDocument());
    return MyProject.fromEntity(newProjectEntity);
  }


  Future<void> deleteProject({required String projectId}) async {
    final projectRef = projectCollection.doc(projectId);
    final filesSnapshot = await projectRef.collection('files').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in filesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(projectRef);
    await batch.commit();
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

// Dentro la classe FirestoreStorageService

  /// Gestisce la visibilità di un progetto, separando la creazione del documento
  /// dalla copia dei file per rispettare le regole di sicurezza di Firestore.
  Future<void> updateProjectVisibility({
    required String projectId,
    required bool isPublic,
  }) async {
    final privateProjectRef = projectCollection.doc(projectId);
    final publicProjectRef = FirebaseFirestore.instance.collection('publicProjects').doc(projectId);
    final visibilityChangeTimestamp = FieldValue.serverTimestamp();

    if (isPublic) {
      // --- CASO: IL PROGETTO VIENE RESO PUBBLICO ---

      // 1. Leggi tutti i dati necessari DAL PRIVATO prima di scrivere
      final projectSnapshot = await privateProjectRef.get();
      if (!projectSnapshot.exists) {
        throw Exception('Progetto con ID $projectId non trovato.');
      }
      final privateFilesSnapshot = await privateProjectRef.collection('files').get();

      // 2. Prepara i dati per la copia pubblica
      final projectDataForPublicCopy = projectSnapshot.data()!;
      projectDataForPublicCopy['isPublic'] = true;
      projectDataForPublicCopy['lastVisibilityChange'] = visibilityChangeTimestamp;

      // ---- PRIMA OPERAZIONE: CREA IL DOCUMENTO GENITORE ----
      // Creiamo prima il documento del progetto pubblico. Questa operazione DEVE
      // essere completata prima di poter scrivere nella sua sottocollezione.
      await publicProjectRef.set(projectDataForPublicCopy);

      // ---- SECONDA OPERAZIONE: COPIA I FILE CON UN NUOVO BATCH ----
      // Ora che il documento genitore esiste, le regole di sicurezza per i file funzioneranno.
      final filesBatch = FirebaseFirestore.instance.batch();
      for (final fileDoc in privateFilesSnapshot.docs) {
        final publicFileRef = publicProjectRef.collection('files').doc(fileDoc.id);
        filesBatch.set(publicFileRef, fileDoc.data());
      }
      await filesBatch.commit(); // Esegui il batch per i file

      // 3. Infine, aggiorna il documento privato originale
      await privateProjectRef.update({
        'isPublic': true,
        'lastVisibilityChange': visibilityChangeTimestamp,
      });

    } else {
      // --- CASO: IL PROGETTO VIENE RESO PRIVATO (può rimanere un singolo batch) ---
      final deleteBatch = FirebaseFirestore.instance.batch();
      final publicFilesSnapshot = await publicProjectRef.collection('files').get();

      for (final fileDoc in publicFilesSnapshot.docs) {
        deleteBatch.delete(fileDoc.reference);
      }
      deleteBatch.delete(publicProjectRef);

      deleteBatch.update(privateProjectRef, {
        'isPublic': false,
        'lastVisibilityChange': visibilityChangeTimestamp,
      });

      await deleteBatch.commit();
    }
  }

  Future<MyProject?> getPublicProjectById(String projectId) async {
    final cleanProjectId = projectId.trim();
    if (cleanProjectId.isEmpty) {
      return null;
    }
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('publicProjects')
          .doc(cleanProjectId)
          .get();

      if (docSnapshot.exists) {
        return MyProject.fromEntity(MyProjectEntity.fromDocument(docSnapshot.data()!));
      } else {
        return null;
      }
    } catch (e) {
      print('Errore in getPublicProjectById: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPublicProjectWithFiles(String projectId) async {
    final cleanId = projectId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final publicProjectRef = FirebaseFirestore.instance.collection('publicProjects').doc(cleanId);

      // 1. Leggi il documento del progetto principale
      final projectDoc = await publicProjectRef.get();
      if (!projectDoc.exists || projectDoc.data()?['isPublic'] != true) {
        // Se il progetto non esiste o non è esplicitamente pubblico, non restituire nulla
        return null;
      }

      // 2. Leggi tutti i documenti nella sottocollezione 'files'
      final filesSnapshot = await publicProjectRef.collection('files').get();

      // 3. Converti i documenti Firestore nei nostri modelli Dart
      final project = MyProject.fromEntity(MyProjectEntity.fromDocument(projectDoc.data()!));
      final files = filesSnapshot.docs
          .map((doc) => MyFile.fromEntity(MyFileEntity.fromDocument(doc.data())))
          .toList();

      // 4. Restituisci una mappa contenente sia il progetto che i file
      return {'project': project, 'files': files};

    } catch (e) {
      print('Errore in getPublicProjectWithFiles: $e');
      rethrow; // Rilancia l'errore per essere gestito dal BLoC
    }
  }
}

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

  /// Restituisce uno stream di tutti i progetti dell'utente, ordinati per ultimo accesso.
  /// Emette una nuova lista ogni volta che i dati cambiano su Firestore.
  Stream<List<MyProject>> projects() {
    return projectCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MyProject.fromEntity(MyProjectEntity.fromDocument(doc.data()!)))
            .toList());
  }

  /// Ottiene il documento Firestore di un singolo progetto.
  /// Utilizzato per verificare l'esistenza o leggere i metadati del progetto.
  Future<DocumentSnapshot<Map<String, dynamic>>> getProjectDoc(String projectId) {
    return projectCollection.doc(projectId).get();
  }

  /// Crea un nuovo progetto con il nome specificato.
  /// Genera automaticamente un UUID, imposta la data corrente e lo marca come privato.
  Future<MyProject> createProject({required String name}) async {
    final projectId = const Uuid().v4();
    final now = DateTime.now();
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

  /// Elimina un progetto e tutti i suoi file associati.
  /// Usa un'operazione batch per garantire atomicità (tutto o niente).
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

  /// Rinomina un progetto esistente.
  /// Aggiorna solo il campo 'name' senza modificare altri metadati.
  Future<void> renameProject(
      {required String projectId, required String newName}) async {
    await projectCollection.doc(projectId).update({'name': newName});
  }

  /// Aggiorna il campo updatedAt del progetto (usato per ordinare per ultimo accesso)
  Future<void> updateProjectAccessTime(String projectId) async {
    await projectCollection.doc(projectId).update({'updatedAt': Timestamp.now()});
  }

  // --- Gestione File ---

  /// Ottiene tutti i file di un progetto come lista di modelli MyFile.
  /// Carica l'intero contenuto di ogni file dalla subcollection 'files'.
  Future<List<MyFile>> getProjectFiles({required String projectId}) async {
    final snapshot =
    await projectCollection.doc(projectId).collection('files').get();
    return snapshot.docs
        .map((doc) => MyFile.fromEntity(MyFileEntity.fromDocument(doc.data())))
        .toList();
  }

  /// Ottiene tutti i file di un progetto come mappa {fileId -> dati grezzi}.
  /// Formato ottimizzato per inizializzare sessioni RTDB o operazioni batch.
  Future<Map<String, Map<String, dynamic>>> getProjectFilesAsMap({required String projectId}) async {
    final snapshot = await projectCollection.doc(projectId).collection('files').get();
    return {for (var doc in snapshot.docs) doc.id: doc.data()};
  }

  /// Aggiunge un nuovo file al progetto specificato.
  /// Genera automaticamente un UUID per il file e lo salva in Firestore.
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

  /// Elimina un file da un progetto.
  /// Rimuove solo il file specificato, senza toccare altri file o il progetto.
  Future<void> deleteFile(
      {required String projectId, required String fileId}) async {
    await projectCollection
        .doc(projectId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

  /// Rinomina un file esistente.
  /// Aggiorna solo il campo 'name' senza modificare il contenuto.
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
  /// Aggiorna anche il campo updatedAt del progetto per tracciare l'ultimo accesso.
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

    // Aggiorna updatedAt ogni volta che i file vengono sincronizzati
    batch.update(projectCollection.doc(projectId), {'updatedAt': Timestamp.now()});
    await batch.commit();
  }

  /// Aggiorna il contenuto di un singolo file e il timestamp del progetto.
  /// Usa un batch per garantire che entrambe le operazioni avvengano insieme.
  Future<void> updateFileContent(
      {required String projectId,
        required String fileId,
        required String content}) async {
    final batch = FirebaseFirestore.instance.batch();

    // Aggiorna il contenuto del file
    batch.update(
      projectCollection.doc(projectId).collection('files').doc(fileId),
      {'content': content}
    );

    // Aggiorna updatedAt del progetto
    batch.update(
      projectCollection.doc(projectId),
      {'updatedAt': Timestamp.now()}
    );

    await batch.commit();
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

  /// Recupera un progetto pubblico dal suo ID.
  /// Cerca nella collection 'publicProjects' separata. Restituisce null se non trovato.
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
      rethrow;
    }
  }

  /// Recupera un progetto pubblico con tutti i suoi file.
  /// Restituisce una mappa {project: MyProject, files: List<MyFile>} o null se non trovato/privato.
  Future<Map<String, dynamic>?> getPublicProjectWithFiles(String projectId) async {
    final cleanId = projectId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final publicProjectRef = FirebaseFirestore.instance.collection('publicProjects').doc(cleanId);
      final projectDoc = await publicProjectRef.get();
      if (!projectDoc.exists || projectDoc.data()?['isPublic'] != true) {
        return null;
      }
      final filesSnapshot = await publicProjectRef.collection('files').get();
      final project = MyProject.fromEntity(MyProjectEntity.fromDocument(projectDoc.data()!));
      final files = filesSnapshot.docs
          .map((doc) => MyFile.fromEntity(MyFileEntity.fromDocument(doc.data())))
          .toList();
      return {'project': project, 'files': files};

    } catch (e) {
      rethrow;
    }
  }
}

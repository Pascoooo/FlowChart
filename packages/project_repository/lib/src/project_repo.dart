import 'package:file_repository/file_repository.dart';
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


/// Definisce il contratto di alto livello per la gestione dei dati dei progetti.
/// Nasconde la complessità della doppia gestione Firestore/RTDB.
abstract class ProjectRepo {
  // --- Logica di Sessione e Recupero ---

  /// Controlla se esiste una sessione di lavoro non salvata.
  Future<PendingSessionInfo?> checkForPendingSessions();

  /// Salva tutte le modifiche della sessione live nello storage permanente.
  Future<void> recoverSession(String projectId);

  /// Scarta tutte le modifiche della sessione live.
  Future<void> discardSession(String projectId);

  /// Inizia una sessione di lavoro, preparando i dati live.
  Future<void> startWorkspaceSession(MyProject project);

  /// Termina una sessione di lavoro, salvando le modifiche.
  Future<void> endWorkspaceSession(String projectId);

  /// Salva il contenuto di un singolo file dalla sessione live allo storage.
  Future<void> recoverSingleFile({required String projectId, required String fileId, required String rtdbContent});

  /// Scarta le modifiche di un singolo file dalla sessione live.
  Future<void> discardSingleFileChange({required String projectId, required String fileId});

  // --- Gestione Progetti (CRUD) ---

  /// Stream che emette la lista dei progetti dell'utente.
  Stream<List<MyProject>> projects();

  /// Crea un nuovo progetto.
  Future<MyProject> createProject({required String name});

  /// Elimina un progetto e tutti i suoi file associati.
  Future<void> deleteProject({required String projectId});

  /// Rinomina un progetto.
  Future<void> renameProject({required String projectId, required String newName});

  // --- Gestione File (CRUD Intelligente) ---

  /// Ottiene la lista dei file di un progetto dallo storage permanente.
  Future<List<MyFile>> getProjectFiles({required String projectId});

  /// Aggiunge un nuovo file al progetto (sia su storage che sulla sessione live, se attiva).
  Future<MyFile> addFileToProject({required String projectId, required String fileName, required String content});

  /// Elimina un file dal progetto (sia da storage che dalla sessione live, se attiva).
  Future<void> deleteFile({required String projectId, required String fileId});

  /// Rinomina un file nel progetto (sia su storage che sulla sessione live, se attiva).
  Future<void> renameFile({required String projectId, required String fileId, required String newName});

  // --- Gestione Contenuto Live ---

  /// Stream per ricevere in tempo reale il contenuto del file su cui si sta lavorando.
  Stream<String?> liveFileContent(String projectId, String fileId);

  /// Aggiorna in tempo reale il contenuto del file su cui si sta lavorando.
  Future<void> updateLiveFileContent(String projectId, String fileId, String content);

  // CONDIVISIONE PROGETTI
  Future<void> updateProjectVisibility({required String projectId, required bool isPublic});
  Future<MyProject?> getPublicProjectById(String projectId);


  Future<Map<String, dynamic>?> getPublicProjectWithFiles(String projectId);
}
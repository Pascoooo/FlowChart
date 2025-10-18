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
  Future<PendingSessionInfo?> checkForPendingSessions();
  Future<void> recoverSession(String projectId);
  Future<void> discardSession(String projectId);
  Future<void> startWorkspaceSession(MyProject project);
  Future<void> endWorkspaceSession(String projectId);
  Future<void> recoverSingleFile({required String projectId, required String fileId, required String rtdbContent});
  Future<void> discardSingleFileChange({required String projectId, required String fileId});

  // --- Gestione Progetti (CRUD) ---
  Stream<List<MyProject>> projects();
  Future<MyProject> createProject({required String name});
  Future<void> deleteProject({required String projectId});
  Future<void> renameProject({required String projectId, required String newName});

  // --- Gestione File (CRUD Intelligente) ---
  Future<List<MyFile>> getProjectFiles({required String projectId});
  Future<MyFile> addFileToProject({required String projectId, required String fileName, required String content});
  Future<void> deleteFile({required String projectId, required String fileId});
  Future<void> renameFile({required String projectId, required String fileId, required String newName});

  // --- Gestione Contenuto Live ---
  Stream<String?> liveFileContent(String projectId, String fileId);
  Future<void> updateLiveFileContent(String projectId, String fileId, String content);

  // --- CONDIVISIONE PROGETTI ---
  Future<void> updateProjectVisibility({required String projectId, required bool isPublic});
  Future<MyProject?> getPublicProjectById(String projectId);
  Future<Map<String, dynamic>?> getPublicProjectWithFiles(String projectId);
}
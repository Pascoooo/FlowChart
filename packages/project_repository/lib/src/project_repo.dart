import 'package:file_repository/file_repository.dart';
import '../project_repository.dart';

/// Definisce il contratto per la gestione dei dati dei progetti.
abstract class ProjectRepo {
  // --- Gestione Sessione Workspace ---

  Future<PendingSessionInfo?> checkForPendingSessions();
  Future<void> recoverSession(String projectId);
  Future<void> discardSession(String projectId);
  Future<void> startWorkspaceSession(MyProject project);
  Future<void> endWorkspaceSession(String projectId);

  // --- NUOVI: Metodi per manipolare la sessione RTDB in tempo reale ---

  /// Aggiunge un file alla sessione RTDB attiva.
  Future<void> addFileToSession(String projectId, MyFile file);

  /// Rimuove un file dalla sessione RTDB attiva.
  Future<void> removeFileFromSession(String projectId, String fileId);

  /// Rinomina un file nella sessione RTDB attiva.
  Future<void> renameFileInSession(String projectId, String fileId, String newName);

  // --- Gestione Progetti (CRUD) ---

  Stream<List<MyProject>> projects();
  Future<MyProject> createProject({required String name});
  Future<void> deleteProject({required String projectId});
  Future<void> renameProject({required String projectId, required String newName});

  // --- Gestione File (CRUD) ---

  Future<List<MyFile>> getProjectFiles({required String projectId});
  /// Modificato: ora restituisce il file creato.
  Future<MyFile> addFileToProject({required String projectId, required String fileName, required String content});
  Future<void> deleteFile({required String projectId, required String fileId});
  Future<void> renameFile({required String projectId, required String fileId, required String newName});

  // --- Gestione Realtime (Contenuto Live) ---

  Stream<String?> liveFileContent(String projectId, String fileId);
  Future<void> updateLiveFileContent(String projectId, String fileId, String content);
}
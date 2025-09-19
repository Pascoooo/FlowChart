import 'package:file_repository/file_repository.dart';
import '../project_repository.dart';

/// Definisce il contratto per la gestione dei dati dei progetti.
abstract class ProjectRepo {

  /// Controlla se esiste una sessione di lavoro non salvata in RTDB.
  /// Restituisce le informazioni del progetto se il "banco di lavoro" è più recente dell' "archivio".
  Future<PendingSessionInfo?> checkForPendingSessions();

  /// Copia i dati dalla sessione RTDB a Firestore ("recupera" il lavoro).
  Future<void> recoverSession(String projectId);

  /// Elimina la sessione non salvata da RTDB ("scarta" il lavoro).
  Future<void> discardSession(String projectId);

  /// Prepara il "banco di lavoro": copia i file da Firestore a RTDB per iniziare.
  Future<void> startWorkspaceSession(MyProject project);

  /// Finalizza il lavoro: salva i dati da RTDB a Firestore e pulisce il "banco di lavoro".
  Future<void> endWorkspaceSession(String projectId);

  // --- Manipolazione Sessione RTDB in tempo reale ---

  /// Aggiunge un file al "banco di lavoro" (sessione RTDB).
  Future<void> addFileToSession(String projectId, MyFile file);

  /// Rimuove un file dal "banco di lavoro" (sessione RTDB).
  Future<void> removeFileFromSession(String projectId, String fileId);

  /// Rinomina un file nel "banco di lavoro" (sessione RTDB).
  Future<void> renameFileInSession(String projectId, String fileId, String newName);

  // --- Gestione Recupero Manuale ---
  /// Sovrascrive un singolo file in Firestore con il contenuto da RTDB.
  Future<void> recoverSingleFile({required String projectId, required String fileId, required String rtdbContent});

  /// Rimuove un singolo file dalla sessione RTDB, scartando le modifiche.
  Future<void> discardSingleFileChange({required String projectId, required String fileId});

  // --- Gestione Progetti (CRUD su Firestore) ---

  Stream<List<MyProject>> projects();
  Future<MyProject> createProject({required String name});
  Future<void> deleteProject({required String projectId});
  Future<void> renameProject({required String projectId, required String newName});

  // --- Gestione File (CRUD su Firestore) ---

  Future<List<MyFile>> getProjectFiles({required String projectId});
  Future<MyFile> addFileToProject({required String projectId, required String fileName, required String content});
  Future<void> deleteFile({required String projectId, required String fileId});
  Future<void> renameFile({required String projectId, required String fileId, required String newName});

  // --- Gestione Realtime (Lavoro sul "banco di lavoro") ---

  /// Ascolta le modifiche al contenuto di un file nella sessione RTDB.
  Stream<String?> liveFileContent(String projectId, String fileId);

  /// Aggiorna il contenuto di un file nella sessione RTDB.
  Future<void> updateLiveFileContent(String projectId, String fileId, String content);
}
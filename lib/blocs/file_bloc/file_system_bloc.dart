import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';

/// Gestisce lo stato dei file all'interno di un progetto attivo.
/// Orchestra le operazioni sull' "archivio" (Firestore) e sul "banco di lavoro" (RTDB).
class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final ProjectRepo projectRepository;

  FileSystemBloc({required this.projectRepository})
      : super(const FileSystemInitial()) {
    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateNewFile>(_onCreateNewFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);
  }

  /// Ricarica la lista dei file da Firestore (l'archivio).
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event, Emitter<FileSystemState> emit) async {
    emit(const FileSystemLoading());
    try {
      final files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e) {
      emit(const FileSystemError(message: 'Errore nel caricamento dei file'));
    }
  }

  /// Crea un file in Firestore, lo aggiunge alla sessione RTDB e lo apre.
  Future<void> _onCreateNewFile(
      CreateNewFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      // 1. Crea il contenuto di default con la forma "Start"
      final String startShapeId = 'start_${DateTime.now().microsecondsSinceEpoch}';
      final Map<String, dynamic> defaultShapeData = {
        'id': startShapeId, 'type': 'circle', 'x': 120.0, 'y': 120.0,
        'properties': {'width': 90.0, 'height': 90.0, 'text': 'Start'},
      };
      final String initialContent = jsonEncode([defaultShapeData]);

      // 2. Salva il file nell'ARCHIVIO (Firestore)
      final newFile = await projectRepository.addFileToProject(
          projectId: event.projectId,
          fileName: event.fileName.trim(),
          content: initialContent);

      // 3. Aggiorna il BANCO DI LAVORO (RTDB)
      await projectRepository.addFileToSession(event.projectId, newFile);

      // 4. Aggiorna lo stato della UI
      final updatedFiles = List<MyFile>.from(currentState.files)..add(newFile);
      emit(FileSystemLoaded(files: updatedFiles, activeFileId: newFile.fileId));

    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Impossibile creare il file.'));
    }
  }

  /// Imposta un file come attivo nello stato.
  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      emit((state as FileSystemLoaded).copyWith(activeFileId: event.fileId));
    }
  }

  /// Elimina un file da Firestore e dalla sessione RTDB.
  Future<void> _onDeleteFile(
      DeleteFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      // 1. Rimuovi dall'ARCHIVIO (Firestore)
      await projectRepository.deleteFile(
          fileId: event.fileId, projectId: event.projectId);

      // 2. Rimuovi dal BANCO DI LAVORO (RTDB)
      await projectRepository.removeFileFromSession(event.projectId, event.fileId);

      // 3. Aggiorna lo stato della UI
      final updatedFiles = currentState.files.where((f) => f.fileId != event.fileId).toList();
      String? nextActiveFileId = currentState.activeFileId;

      // Se il file eliminato era quello attivo, seleziona il primo file disponibile
      if (currentState.activeFileId == event.fileId) {
        nextActiveFileId = updatedFiles.isNotEmpty ? updatedFiles.first.fileId : null;
      }

      emit(FileSystemLoaded(files: updatedFiles, activeFileId: nextActiveFileId));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante l\'eliminazione.'));
    }
  }

  /// Rinomina un file in Firestore e nella sessione RTDB.
  Future<void> _onRenameFile(
      RenameFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      final newName = event.newName.trim();
      // 1. Rinomina nell'ARCHIVIO (Firestore)
      await projectRepository.renameFile(
          fileId: event.fileId, newName: newName, projectId: event.projectId);

      // 2. Rinomina nel BANCO DI LAVORO (RTDB)
      await projectRepository.renameFileInSession(
          event.projectId, event.fileId, newName);

      // 3. Aggiorna lo stato della UI
      final updatedFiles = currentState.files.map((f) {
        return f.fileId == event.fileId ? MyFile(fileId: f.fileId, name: newName, content: f.content)
            : f;
      }).toList();

      emit(currentState.copyWith(files: updatedFiles, isLoading: false));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }
}
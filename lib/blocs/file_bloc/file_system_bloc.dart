import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';

/// Gestisce lo stato dell'elenco dei file per un progetto attivo.
/// Orchestra le operazioni sul repository per modificare l' "archivio" (Firestore)
/// e il "banco di lavoro" (RTDB) in modo coordinato.
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

  /// Carica o ricarica la lista dei file del progetto dallo storage permanente.
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event, Emitter<FileSystemState> emit) async {
    emit(const FileSystemLoading());
    try {
      final files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e) {
      emit(const FileSystemError(message: 'Errore nel caricamento dei file.'));
    }
  }

  /// Crea un nuovo file con un contenuto di default, lo salva e lo imposta come attivo.
  Future<void> _onCreateNewFile(
      CreateNewFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      final String startShapeId = 'start_${DateTime.now().microsecondsSinceEpoch}';
      final Map<String, dynamic> defaultShapeData = {
        'id': startShapeId,
        'type': 'circle',
        'x': 120.0,
        'y': 120.0,
        'properties': {'width': 90.0, 'height': 90.0, 'text': 'Start'},
      };
      final Map<String, dynamic> initialContentData = {
        'shapes': [defaultShapeData],
      };
      final String initialContent = jsonEncode(initialContentData);

      final newFile = await projectRepository.addFileToProject(
        projectId: event.projectId,
        fileName: event.fileName.trim(),
        content: initialContent,
      );

      final updatedFiles = List<MyFile>.from(currentState.files)..add(newFile);
      emit(FileSystemLoaded(
        files: updatedFiles,
        activeFileId: newFile.fileId,
        isLoading: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Impossibile creare il file. Dettagli: ${e.toString()}'));
    }
  }

  /// Imposta un file come attivo nello stato corrente.
  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      emit((state as FileSystemLoaded).copyWith(activeFileId: event.fileId));
    }
  }

  /// Elimina un file dallo storage e dalla sessione live.
  Future<void> _onDeleteFile(
      DeleteFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      await projectRepository.deleteFile(
          projectId: event.projectId, fileId: event.fileId);

      final updatedFiles = currentState.files.where((f) => f.fileId != event.fileId).toList();
      String? nextActiveFileId = currentState.activeFileId;

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
      await projectRepository.renameFile(
          projectId: event.projectId, fileId: event.fileId, newName: newName);
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
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:project_repository/project_repository.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';


class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final ProjectRepo projectRepository;

  FileSystemBloc({required this.projectRepository})
      : super(const FileSystemInitial()) {

    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateNewFile>(_onCreateNewFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);
    on<UpdateFileContent>(_onUpdateFileContent);
  }

  /// Ricarica l'intero filesystem per un progetto specifico
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files, activeFileId: null));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nel caricamento dei file', emit);
    }
  }

  /// Gestisce la creazione di un nuovo file
  Future<void> _onCreateNewFile(
      CreateNewFile event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      if (event.fileName.trim().isEmpty) {
        throw Exception('Il nome del file non può essere vuoto.');
      }

      String fileName = event.fileName.trim();
      await projectRepository.addFileToProject(
        projectId: event.projectId,
        fileName: fileName,
        content: '',
      );
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella creazione del file', emit);
    }
  }

  /// Gestisce l'apertura di un file
  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      final loadedState = state as FileSystemLoaded;
      emit(loadedState.copyWith(
        activeFileId: event.fileId,
        successMessage: 'File "${event.fileName}" aperto.',
      ));
    }
  }

  /// Elimina un file
  Future<void> _onDeleteFile(
      DeleteFile event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      await projectRepository.deleteFile(fileId: event.fileId, projectId: event.projectId);
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nell\'eliminazione del file', emit);
    }
  }

  /// Rinomina un file
  Future<void> _onRenameFile(
      RenameFile event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      if (event.newName.trim().isEmpty) {
        throw Exception('Il nuovo nome non può essere vuoto.');
      }
      await projectRepository.renameFile(
          fileId: event.fileId, newName: event.newName.trim(), projectId: event.projectId);
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella ridenominazione', emit);
    }
  }

  /// Aggiorna il contenuto di un file
  Future<void> _onUpdateFileContent(
      UpdateFileContent event,
      Emitter<FileSystemState> emit,
      ) async {
    if (state is FileSystemLoaded) {
      final loadedState = state as FileSystemLoaded;
      try {
        await projectRepository.updateFileContent(
            projectId: event.projectId,
            fileId: event.fileId,
            newContent: event.newContent);
        emit(loadedState.copyWith(
            successMessage: 'Contenuto salvato con successo.'));
      } catch (e, stackTrace) {
        _handleError(e, stackTrace, 'Errore nel salvataggio del contenuto', emit);
      }
    }
  }

  /// Funzione helper per la gestione degli errori
  void _handleError(
      Object e, StackTrace stackTrace, String prefix, Emitter<FileSystemState> emit) {
    if (kDebugMode) {
      debugPrint('$prefix: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
    emit(FileSystemError(message: '$prefix: $e'));
  }
}
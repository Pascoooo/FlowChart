import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
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
  }

  /// Ricarica la lista dei file da Firestore.
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

  /// Gestisce la creazione di un nuovo file in Firestore e nella sessione RTDB.
  Future<void> _onCreateNewFile(
      CreateNewFile event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      String fileName = event.fileName.trim();
      await projectRepository.addFileToProject(
        projectId: event.projectId,
        fileName: fileName,
        content: '',
      );
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      await projectRepository.addFileToSession(event.projectId, files.last);
      emit(FileSystemLoaded(files: files));
    } catch (e) {
      emit (const FileSystemError(message: 'Errore nella creazione del file'));
    }
  }

  /// Imposta un file come attivo.
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
      await projectRepository.deleteFile(
          fileId: event.fileId, projectId: event.projectId);
      await projectRepository.removeFileFromSession(
          event.projectId, event.fileId);

      final updatedFiles =
      currentState.files.where((f) => f.fileId != event.fileId).toList();
      String? nextActiveFileId = currentState.activeFileId;

      if (currentState.activeFileId == event.fileId) {
        nextActiveFileId =
        updatedFiles.isNotEmpty ? updatedFiles.first.fileId : null;
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
          fileId: event.fileId, newName: newName, projectId: event.projectId);
      await projectRepository.renameFileInSession(
          event.projectId, event.fileId, newName);

      final updatedFiles = currentState.files.map((f) {
        return f.fileId == event.fileId ? MyFile(fileId: f.fileId, name: newName, content: f.content)
            : f;
      }).toList();

      emit(FileSystemLoaded(
          files: updatedFiles, activeFileId: currentState.activeFileId));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }
}
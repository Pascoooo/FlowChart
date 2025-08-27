import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flutter/foundation.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';


class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final FirebaseFileRepo fileRepository;

  FileSystemBloc({required this.fileRepository})
      : super(const FileSystemInitial()) {

    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateNewFile>(_onCreateNewFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);

    // Esegui l'aggiornamento iniziale all'avvio
    add(const RefreshFileSystem());
  }

  /// Ricarica l'intero filesystem
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      final List<MyFile> files = await fileRepository.getFiles();
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
      // Validazione del nome
      if (event.fileName.trim().isEmpty) {
        throw Exception('Il nome del file non può essere vuoto.');
      }

      String fileName = event.fileName.trim();
      await fileRepository.createFile(name: fileName);
      final List<MyFile> files = await fileRepository.getFiles();
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
      await fileRepository.deleteFile(fileId: event.fileId);
      final List<MyFile> files = await fileRepository.getFiles();
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
      await fileRepository.renameFile(
          fileId: event.fileId, newName: event.newName.trim());
      final List<MyFile> files = await fileRepository.getFiles();
      emit(FileSystemLoaded(files: files));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella ridenominazione', emit);
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
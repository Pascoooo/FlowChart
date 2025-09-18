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
    } catch (e) {
      emit(const FileSystemError(message: 'Errore nel caricamento dei file'));
    }
  }

  /// Gestisce la creazione di un nuovo file
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
      emit(FileSystemLoaded(files: files));
    } catch (e) {
      emit (const FileSystemError(message: 'Errore nella creazione del file'));
    }
  }

  /// Gestisce l'apertura di un file
  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      final loadedState = state as FileSystemLoaded;
      emit(loadedState.copyWith(
        activeFileId: event.fileId,
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
    } catch (e) {
      emit (const FileSystemError(message: 'Errore nella cancellazione del file'));
    }
  }

  /// Rinomina un file
  Future<void> _onRenameFile(
      RenameFile event,
      Emitter<FileSystemState> emit,
      ) async {
    emit(const FileSystemLoading());
    try {
      await projectRepository.renameFile(
          fileId: event.fileId, newName: event.newName.trim(), projectId: event.projectId);
      final List<MyFile> files = await projectRepository.getProjectFiles(projectId: event.projectId);
      emit(FileSystemLoaded(files: files));
    } catch (e) {
      emit (const FileSystemError(message: 'Errore nella rinominazione del file'));
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
      } catch (e) {
        emit(loadedState.copyWith(
            error: 'Errore nel salvataggio del contenuto.'));
      }
    }
  }
}
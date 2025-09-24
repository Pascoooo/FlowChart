import 'dart:convert';
import 'dart:ui';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:uuid/uuid.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart';
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
      // 1. Usa la NUOVA Factory per creare il nodo di start di default.
      final startNode = FlowNodeFactory.createNode(
        FlowNodeKind.start,
        const Offset(120.0, 120.0),
      );

      // 2. Crea un oggetto Flowchart completo, usando il nome del file dall'evento.
      final initialFlowchart = Flowchart(
        flowchartId: const Uuid().v4(),
        name: event.fileName.trim(), // Il nome del flowchart è il nome del file
        schemaVersion: kFlowNodeSchemaVersion,
        nodes: [startNode], // Il flowchart contiene solo il nodo di start
        edges: const [],
      );

      // 3. Serializza il nuovo oggetto Flowchart in una stringa JSON.
      final initialContent = jsonEncode(initialFlowchart.toEntity().toDocument());

      // 4. Salva il file nel repository.
      final newFile = await projectRepository.addFileToProject(
        projectId: event.projectId,
        fileName: event.fileName.trim(),
        content: initialContent,
      );

      // 5. Aggiorna lo stato: aggiungi il file alla lista e impostalo come attivo.
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
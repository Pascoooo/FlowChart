import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flutter/material.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart';
import '../flowchart_bloc/flowchart_state.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';

class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final ProjectRepo projectRepository;

  FileSystemBloc({required this.projectRepository})
      : super(const FileSystemInitial()) {
    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateFile>(_onCreateFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);

    on<StartDebugSession>(_onStartDebugSession);
    on<ComputeDebugStep>(_onComputeDebugStep);
    on<EndDebugSession>(_onEndDebugSession);
  }


// --- SEZIONE DEBUG (AGGIORNATA) ---

  Stream<Map<String, dynamic>> debugVariablesStream(String projectId) {
    return projectRepository.watchDebugVariables(projectId: projectId);
  }

  Future<void> _onStartDebugSession(
      StartDebugSession event, Emitter<FileSystemState> emit) async {
    try {
      await projectRepository.startDebugSession(
          projectId: event.flowchart.flowchartId, flowchart: event.flowchart);
    } catch (e) {
      debugPrint('Errore durante l\'avvio della sessione di debug: $e');
    }
  }

// FIX: Reso più robusto con un try-catch specifico per trovare il nodo.
  Future<void> _onComputeDebugStep(
      ComputeDebugStep event, Emitter<FileSystemState> emit) async {
    try {
      if (event.index < 0 || event.index >= event.debugPath.length) {
        debugPrint('Indice di debug fuori dai limiti.');
        return;
      }
      final currentNodeId = event.debugPath[event.index];

      late final FlowNode currentNode;

      try {
        // Cerca il nodo. Se non lo trova, lancia StateError.
        currentNode = event.flowchart.nodes.firstWhere(
              (n) => n.id == currentNodeId,
        );
      } on StateError {
        // Cattura l'errore se il nodo non viene trovato e interrompe l'esecuzione.
        debugPrint('ERRORE: Nodo di debug non trovato per id: $currentNodeId.');
        return;
      }

      // Se il nodo è stato trovato, chiama il repository.
      await projectRepository.advanceDebugStep(
        projectId: event.flowchart.flowchartId,
        currentNode: currentNode,
      );

    } catch (e) {
      debugPrint('Errore generico durante il calcolo dello step di debug: $e');
    }
  }

  Future<void> _onEndDebugSession(
      EndDebugSession event, Emitter<FileSystemState> emit) async {
    try {
      await projectRepository.endDebugSession(projectId: event.projectId);
    } catch (e) {
      debugPrint('Errore durante la terminazione della sessione di debug: $e');
    }
  }

  // --- SEZIONE CRUD (OPERAZIONI SUI FILE) ---

  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event, Emitter<FileSystemState> emit) async {
    emit(const FileSystemLoading());
    try {
      final files = await projectRepository.getProjectFiles(projectId: event.projectId);
      if (files.isEmpty) {
        final emptyFlowchart = FlowchartLoaded.empty(fileName: 'main').flowchart;
        final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(120.0, 120.0));
        final initialFlowchart = emptyFlowchart.copyWith(nodes: [startNode]);
        final initialContent = jsonEncode(initialFlowchart.toEntity().toDocument());

        final mainFile = await projectRepository.addFileToProject(
          projectId: event.projectId,
          fileName: 'main',
          content: initialContent,
        );
        emit(FileSystemLoaded(files: [mainFile], activeFileId: mainFile.fileId));

      } else {
        final mainFile = files.firstWhere((f) => f.name.toLowerCase() == 'main', orElse: () => files.first);
        emit(FileSystemLoaded(files: files, activeFileId: mainFile.fileId));
      }
    } catch (e) {
      emit(FileSystemError(message: 'Errore nel caricamento dei file: ${e.toString()}'));
    }
  }

  Future<void> _onCreateFile(
      CreateFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;
    final fileName = event.fileName.trim();

    if (fileName.isEmpty) {
      emit(currentState.copyWith(error: 'Il nome del file non può essere vuoto.', clearError: false));
      return;
    }
    if (currentState.files.any((f) => f.name.toLowerCase() == fileName.toLowerCase())) {
      emit(currentState.copyWith(error: 'Un file con questo nome esiste già.', clearError: false));
      return;
    }

    emit(currentState.copyWith(isLoading: true));
    try {
      final emptyFlowchart = FlowchartLoaded.empty(fileName: fileName).flowchart;
      final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(1030.0, 50.0));
      final initialFlowchart = emptyFlowchart.copyWith(nodes: [startNode]);
      final initialContent = jsonEncode(initialFlowchart.toEntity().toDocument());

      final newFile = await projectRepository.addFileToProject(
        projectId: event.projectId,
        fileName: fileName,
        content: initialContent,
      );

      final updatedFiles = [...currentState.files, newFile];
      emit(FileSystemLoaded(
        files: updatedFiles,
        activeFileId: newFile.fileId,
        isLoading: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Impossibile creare il file: ${e.toString()}'));
    }
  }

  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      emit((state as FileSystemLoaded).copyWith(activeFileId: event.fileId));
    }
  }

  Future<void> _onDeleteFile(
      DeleteFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;
    final fileToDelete = currentState.files.firstWhere((f) => f.fileId == event.fileId, orElse: () => MyFile.empty);

    if (fileToDelete.name.toLowerCase() == 'main') {
      emit(currentState.copyWith(error: 'Il file "main" non può essere eliminato.'));
      return;
    }

    emit(currentState.copyWith(isLoading: true));
    try {
      await projectRepository.deleteFile(projectId: event.projectId, fileId: event.fileId);
      final updatedFiles = currentState.files.where((f) => f.fileId != event.fileId).toList();
      String? nextActiveFileId = currentState.activeFileId;

      if (currentState.activeFileId == event.fileId) {
        nextActiveFileId = updatedFiles.isNotEmpty ? updatedFiles.first.fileId : null;
      }

      emit(FileSystemLoaded(files: updatedFiles, activeFileId: nextActiveFileId));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante l\'eliminazione: ${e.toString()}'));
    }
  }

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
        return f.fileId == event.fileId ? MyFile(fileId: f.fileId, name: newName, content: f.content) : f;
      }).toList();

      emit(currentState.copyWith(files: updatedFiles, isLoading: false));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }

}
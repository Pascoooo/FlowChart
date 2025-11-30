/// FileSystem BLoC gestisce le operazioni CRUD sui file di un progetto (flowchart).
/// Coordina creazione, eliminazione, rinomina file e sincronizzazione con il repository.
/// Mantiene lo stato dei file attivi e la cache dei contenuti.
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart';
import '../flowchart_bloc/flowchart_state.dart';
import 'file_system_event.dart';
import 'file_system_state.dart';

class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final ProjectRepo projectRepository;

  /// Inizializza il BLoC con ProjectRepository e registra gli event handler.
  /// Gestisce refresh, CRUD file, validazione progetto e aggiornamenti cache.
  FileSystemBloc({required this.projectRepository})
      : super(const FileSystemInitial()) {
    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateFile>(_onCreateFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);
    on<UpdateFileContentInCache>(_onUpdateFileContentInCache);
  }

  // --- SEZIONE CRUD (OPERAZIONI SUI FILE) ---

  /// Carica tutti i file del progetto da Firebase.
  /// Se non esiste il file 'main', lo crea con un flowchart iniziale contenente solo il nodo Start.
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event, Emitter<FileSystemState> emit) async {
    emit(const FileSystemLoading());
    try {
      final files = await projectRepository.getProjectFiles(projectId: event.projectId);
      if (files.isEmpty) {
        final emptyFlowchart = FlowchartLoaded.empty(fileName: 'main').flowchart;
        final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(1030.0, 50.0), allVariables: []);
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
      // Il progetto viene caricato senza step di validazione esecutiva
    } catch (e) {
      emit(FileSystemError(message: 'Errore nel caricamento dei file: ${e.toString()}'));
    }
  }

  /// Crea un nuovo file nel progetto con flowchart iniziale.
  /// Se signature è null, crea un file "main" con nodo Start; altrimenti crea un sottoprogramma con header e parametri.
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
      // Base: flowchart vuoto con nome corretto
      final baseFlowchart = FlowchartLoaded.empty(fileName: fileName).flowchart;

      Flowchart initialFlowchart;
      if (event.signature == null) {
        // File "main": crea solo il nodo Inizio
        final startNode = FlowNodeFactory.createNode(
          FlowNodeKind.start,
          const Offset(1030.0, 50.0),
          allVariables: const [],
        );
        initialFlowchart = baseFlowchart.copyWith(
          type: FlowchartType.main,
          nodes: [startNode],
        );
      } else {
        // Sottoprogramma: intestazione + variabili di input dai parametri
        final signature = event.signature!;

        final headerNode = FunctionHeaderNode(
          id: 'header-${const Uuid().v4()}',
          x: 1030.0,
          y: 50.0,
          width: 250.0,
          height: 100.0,
          functionName: fileName,
          returnType: signature.returnType,
          parameters: signature.parameters,
        );

        final paramVariables = signature.parameters
            .map((p) => VariableDeclaration(
          name: p.name,
          dataType: p.type,
          scope: VariableScope.params, // REQUISITO: I parametri hanno scope dedicato
        ))
            .toList();

        initialFlowchart = baseFlowchart.copyWith(
          type: FlowchartType.function,
          nodes: [headerNode],
          signature: signature,
          variables: paramVariables,
        );
      }

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
      return;
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Impossibile creare il file: ${e.toString()}'));
    }
  }

  /// Cambia il file attivo corrente nell'editor.
  /// Emette stato aggiornato con il nuovo activeFileId.
  void _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) {
    if (state is FileSystemLoaded) {
      emit((state as FileSystemLoaded).copyWith(activeFileId: event.fileId));
    }
  }

  /// Elimina un file dal progetto, sia da Firestore che da RTDB.
  /// Impedisce l'eliminazione del file "main" e seleziona automaticamente un nuovo file attivo se necessario.
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
      // ✅ FIX CRITICO: Prima rimuovi il file dalla sessione RTDB, poi da Firestore
      // Questo garantisce che quando esci dal workspace, il file eliminato non venga risincronizzato
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

  /// Rinomina un file esistente nel progetto.
  /// Aggiorna il nome sia nel repository che nello stato locale.
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
      // Rinominare un file non cambia la struttura: nessuna invalidazione necessaria
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }


  /// Aggiorna il contenuto di un file nella cache locale (senza persistenza immediata).
  /// Usato per sincronizzare modifiche temporanee prima del salvataggio su Firebase.
  void _onUpdateFileContentInCache(
      UpdateFileContentInCache event, Emitter<FileSystemState> emit) {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    final updatedFiles = currentState.files.map((file) {
      if (file.fileId == event.fileId) {
        return file.copyWith(content: event.newContent);
      }
      return file;
    }).toList();

    emit(currentState.copyWith(files: updatedFiles));
    // UpdateFileContentInCache: aggiornamento temporaneo, non invalidare
  }
}

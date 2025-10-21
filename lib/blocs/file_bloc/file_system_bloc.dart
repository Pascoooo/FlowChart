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

  FileSystemBloc({required this.projectRepository})
      : super(const FileSystemInitial()) {
    on<RefreshFileSystem>(_onRefreshFileSystem);
    on<CreateFile>(_onCreateFile);
    on<OpenFile>(_onOpenFile);
    on<DeleteFile>(_onDeleteFile);
    on<RenameFile>(_onRenameFile);
    on<UpdateFileContentInCache>(_onUpdateFileContentInCache);
    on<ValidateProject>(_onValidateProject);
  }

  // --- SEZIONE CRUD (OPERAZIONI SUI FILE) ---

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
      add(const ValidateProject()); // Attiva la validazione dopo il caricamento
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
          id: 'header-${Uuid().v4()}',
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
          scope: VariableScope.local, // REQUISITO: I parametri sono variabili locali
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
      add(const ValidateProject()); // Attiva la validazione dopo la creazione
      return;
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
      // ✅ FIX CRITICO: Prima rimuovi il file dalla sessione RTDB, poi da Firestore
      // Questo garantisce che quando esci dal workspace, il file eliminato non venga risincronizzato
      await projectRepository.deleteFile(projectId: event.projectId, fileId: event.fileId);

      final updatedFiles = currentState.files.where((f) => f.fileId != event.fileId).toList();
      String? nextActiveFileId = currentState.activeFileId;

      if (currentState.activeFileId == event.fileId) {
        nextActiveFileId = updatedFiles.isNotEmpty ? updatedFiles.first.fileId : null;
      }

      emit(FileSystemLoaded(files: updatedFiles, activeFileId: nextActiveFileId));
      add(const ValidateProject()); // Attiva la validazione dopo l'eliminazione
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
      add(const ValidateProject()); // Attiva la validazione dopo la rinomina
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }


  void _onUpdateFileContentInCache(
      UpdateFileContentInCache event, Emitter<FileSystemState> emit) {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    final updatedFiles = currentState.files.map((file) {
      if (file.fileId == event.fileId) {
        // Assumendo che MyFile abbia un metodo copyWith. Se non ce l'ha, è essenziale aggiungerlo.
        return file.copyWith(content: event.newContent);
      }
      return file;
    }).toList();

    // Emetti il nuovo stato con la lista dei file aggiornata, in modo silenzioso
    emit(currentState.copyWith(files: updatedFiles));
    add(const ValidateProject());
  }

  Future<void> _onValidateProject(
    ValidateProject event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    bool allValid = true;
    try {
      final List<Flowchart> flowcharts = currentState.files.map((file) {
        final jsonContent = jsonDecode(file.content);
        return Flowchart.fromEntity(FlowchartEntity.fromDocument(jsonContent));
      }).toList();

      for (final flowchart in flowcharts) {
        if (!_isFlowchartValid(flowchart, flowcharts)) {
          allValid = false;
          break;
        }
      }
    } catch (e) {
      allValid = false;
      // Puoi gestire l'errore di parsing o validazione qui se necessario
    }

    emit(currentState.copyWith(isProjectValid: allValid));
  }

  bool _isFlowchartValid(Flowchart flowchart, List<Flowchart> allFlowcharts) {
    // 1. Tutti i nodi devono essere raggiungibili dal nodo di partenza
    if (flowchart.nodes.isEmpty) return false; // Un flowchart vuoto non è valido
    final startNode = flowchart.nodes.firstWhere(
        (n) => n.kind == FlowNodeKind.start || n.kind == FlowNodeKind.functionHeader,
        orElse: () => const StartNode(id: '', x: 0, y: 0, width: 0, height: 0, text: '')
    );
    if (startNode.id.isEmpty) return false; // Nessun nodo di partenza

    final visited = <String>{};
    final queue = [startNode.id];
    visited.add(startNode.id);

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final outgoingEdges = flowchart.edges.where((e) => e.from == currentId);
      for (final edge in outgoingEdges) {
        if (!visited.contains(edge.to)) {
          visited.add(edge.to);
          queue.add(edge.to);
        }
      }
    }
    if (visited.length != flowchart.nodes.length) return false;

    // 2. Validazione dei nodi condizionali (cicli e decisioni)
    final conditionalNodes = flowchart.nodes.where((n) =>
        n.kind == FlowNodeKind.whileLoop ||
        n.kind == FlowNodeKind.doWhileLoop ||
        n.kind == FlowNodeKind.decision);

    for (final node in conditionalNodes) {
      final outgoingEdges = flowchart.edges.where((e) => e.from == node.id).toList();
      final hasTrueExit = outgoingEdges.any((e) => e.port == 'true');
      final hasFalseExit = outgoingEdges.any((e) => e.port == 'false');
      if (!hasTrueExit || !hasFalseExit) {
        return false; // Il nodo non ha entrambi i rami (true/false)
      }
    }

    // 3. Validazione dei nodi foglia (nodi senza uscite)
    final leafNodes = flowchart.nodes.where((node) {
      return !flowchart.edges.any((edge) => edge.from == node.id);
    }).toList();

    if (flowchart.type == FlowchartType.main) {
      // Per il main: deve esserci esattamente un nodo foglia, e deve essere un nodo 'end'.
      if (leafNodes.length != 1) return false;
      if (leafNodes.first.kind != FlowNodeKind.end) return false;
    } else {
      // Per i sottoprogrammi: tutti i nodi foglia devono essere di tipo 'return'.
      if (leafNodes.isEmpty) return false; // Un sottoprogramma deve avere almeno un return
      for (final node in leafNodes) {
        if (node.kind != FlowNodeKind.returnNode) return false;
      }
    }

    return true;
  }
}

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
    on<ExecuteActiveFile>(_onExecuteActiveFile);
    on<ClearExecutionCode>(_onClearExecutionCode);
    on<StartDebugSession>(_onStartDebugSession);
    on<ComputeDebugStep>(_onComputeDebugStep);
    on<EndDebugSession>(_onEndDebugSession);
  }

  // --- SEZIONE DEBUG ---

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

// Dentro la classe FileSystemBloc

  /// Gestisce il ricalcolo dello stato di debug a un dato step.
  Future<void> _onComputeDebugStep(
      ComputeDebugStep event, Emitter<FileSystemState> emit) async {
    try {

      // FIX: Logica per trovare il nodo corrente dall'evento
      if (event.index < 0 || event.index >= event.debugPath.length) {
        debugPrint('Indice di debug fuori dai limiti.');
        return;
      }
      final currentNodeId = event.debugPath[event.index];
      final currentNode = event.flowchart.nodes.firstWhere(
            (n) => n.id == currentNodeId,
        // orElse previene errori se il nodo non viene trovato
        orElse: () => FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(0, 0)),
      );

      // FIX: Chiama il metodo corretto definito nell'interfaccia ProjectRepo
      await projectRepository.advanceDebugStep(
        projectId: event.flowchart.flowchartId,
        currentNode: currentNode,
      );

    } catch (e) {
      debugPrint('Errore durante il calcolo dello step di debug: $e');
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


  // --- SEZIONE ESECUZIONE ---

  Future<void> _onExecuteActiveFile(
      ExecuteActiveFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    try {
      final cCode = _generateCCode(event.flowchart);
      emit(currentState.copyWith(executionCode: cCode));
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore durante la generazione del codice: $e'));
    }
  }

  Future<void> _onClearExecutionCode(
      ClearExecutionCode event, Emitter<FileSystemState> emit) async {
    if (state is FileSystemLoaded) {
      emit((state as FileSystemLoaded).copyWith(clearExecutionCode: true));
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
      final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(120.0, 120.0));
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

  // --- SEZIONE GENERAZIONE CODICE C ---

  String _generateCCode(Flowchart flowchart) {
    // ... La tua logica completa di _generateCCode e dei suoi metodi helper ...
    // La incollo qui per completezza dalla tua versione
    final buffer = StringBuffer();
    buffer.writeln('/* Codice generato automaticamente da Unichart */');
    buffer.writeln('#include <stdio.h>');
    buffer.writeln('#include <stdlib.h>');
    buffer.writeln('#include <string.h>');
    buffer.writeln();

    final signature = flowchart.signature;
    buffer.write('${signature.returnType} ${flowchart.name}(');
    if (signature.parameters.isNotEmpty) {
      buffer.write(
          signature.parameters.map((p) => '${p.type} ${p.name}').join(', '));
    }
    buffer.writeln(') {');

    for (final variable in flowchart.variables) {
      buffer.write('    ${variable.dataType} ${variable.name}');
      if (variable.defaultValue != null) {
        final value = variable.defaultValue;
        if (variable.dataType.toLowerCase().contains('char')) {
          buffer.write(' = "$value"');
        } else {
          buffer.write(' = $value');
        }
      }
      buffer.writeln(';');
    }
    if (flowchart.variables.isNotEmpty) buffer.writeln();

    final startNode =
    flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
    final visited = <String>{};
    _generateNodeCode(buffer, flowchart, startNode.id, visited, indent: 1);

    if (signature.returnType != 'void' && !buffer.toString().contains('return')) {
      buffer.writeln('    return 0;');
    }
    buffer.writeln('}');

    return buffer.toString();
  }

  void _generateNodeCode(StringBuffer buffer, Flowchart flowchart, String nodeId,
      Set<String> visited,
      {required int indent}) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);

    final node = flowchart.nodes.firstWhere((n) => n.id == nodeId);
    final indentStr = '    ' * indent;

    switch (node.kind) {
      case FlowNodeKind.start:
        final nextEdge = _findNextEdge(flowchart, nodeId);
        if (nextEdge != null) {
          _generateNodeCode(buffer, flowchart, nextEdge.to, visited,
              indent: indent);
        }
        break;

      case FlowNodeKind.end:
        if (flowchart.signature.returnType != 'void') {
          buffer.writeln('${indentStr}return 0; // Fine flowchart');
        }
        break;

      case FlowNodeKind.input:
        final inputNode = node as InputNode;
        for (final decl in inputNode.declarations) {
          if (decl.dataType.contains('char')) {
            buffer.writeln('${indentStr}scanf("%s", ${decl.name});');
          } else {
            final format = _getScanfFormat(decl.dataType);
            buffer.writeln('${indentStr}scanf("$format", &${decl.name});');
          }
        }
        final nextEdge = _findNextEdge(flowchart, nodeId);
        if (nextEdge != null) {
          _generateNodeCode(buffer, flowchart, nextEdge.to, visited,
              indent: indent);
        }
        break;

      case FlowNodeKind.output:
        final outputNode = node as OutputNode;
        String printfStr = outputNode.template;
        final vars = outputNode.variables;
        if (vars.isNotEmpty) {
          buffer.write('${indentStr}printf("$printfStr\\n"');
          for (final varName in vars) {
            buffer.write(', $varName');
          }
          buffer.writeln(');');
        } else {
          buffer.writeln('${indentStr}printf("$printfStr\\n");');
        }
        final nextEdge = _findNextEdge(flowchart, nodeId);
        if (nextEdge != null) {
          _generateNodeCode(buffer, flowchart, nextEdge.to, visited,
              indent: indent);
        }
        break;

      case FlowNodeKind.process:
        final processNode = node as ProcessNode;
        if (processNode.flowchartToCall.isNotEmpty) {
          final args = processNode.arguments.join(', ');
          if (processNode.resultTarget != null &&
              processNode.resultTarget!.isNotEmpty) {
            buffer.writeln(
                '$indentStr${processNode.resultTarget} = ${processNode.flowchartToCall}($args);');
          } else {
            buffer.writeln('$indentStr${processNode.flowchartToCall}($args);');
          }
        }
        final nextEdge = _findNextEdge(flowchart, nodeId);
        if (nextEdge != null) {
          _generateNodeCode(buffer, flowchart, nextEdge.to, visited,
              indent: indent);
        }
        break;

      case FlowNodeKind.decision:
        final decisionNode = node as DecisionNode;
        buffer.writeln('${indentStr}if (${decisionNode.condition}) {');
        final trueEdge = flowchart.edges.firstWhere(
                (e) => e.from == nodeId && e.port == 'true',
            orElse: () => const FlowchartEdge(from: '', to: ''));
        if (trueEdge.from.isNotEmpty) {
          _generateNodeCode(buffer, flowchart, trueEdge.to, visited,
              indent: indent + 1);
        }
        buffer.writeln('$indentStr} else {');
        final falseEdge = flowchart.edges.firstWhere(
                (e) => e.from == nodeId && e.port == 'false',
            orElse: () => const FlowchartEdge(from: '', to: ''));
        if (falseEdge.from.isNotEmpty) {
          _generateNodeCode(buffer, flowchart, falseEdge.to, visited,
              indent: indent + 1);
        }
        buffer.writeln('$indentStr}');
        break;
    }
  }

  FlowchartEdge? _findNextEdge(Flowchart flowchart, String fromNodeId) {
    try {
      return flowchart.edges.firstWhere((e) => e.from == fromNodeId && e.port == null);
    } catch (_) {
      return null;
    }
  }

  String _getScanfFormat(String dataType) {
    if (dataType.contains('int')) return '%d';
    if (dataType.contains('float')) return '%f';
    if (dataType.contains('double')) return '%lf';
    if (dataType.contains('char') && !dataType.contains('[')) return '%c';
    return '%d';
  }
}
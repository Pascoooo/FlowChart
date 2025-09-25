import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
// Importiamo le classi Entity per un accesso più semplice e sicuro ai dati
import 'package:flowchart_repository/src/entities/flowchart_entity.dart';
import 'package:flowchart_repository/src/entities/flow_node_entity.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart';
import '../flowchart_bloc/flowchart_state.dart';
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
    on<ExecuteActiveFile>(_onExecuteActiveFile);
  }

  /// **GENERATORE DI CODICE C STRUTTURATO (CORRETTO)**
  String _generateCCode(String jsonContent) {
    try {
      final flowchart = FlowchartEntity.fromDocument(jsonDecode(jsonContent));
      final code = StringBuffer();
      final visitedNodes = <String>{}; // Per evitare duplicazioni e loop

      // --- Helpers ---
      String mapDataType(String type) {
        switch (type) {
          case 'float': return 'float';
          case 'string': return 'char';
          default: return 'int';
        }
      }

      String mapTypeToFormatSpecifier(String type) {
        switch (type) {
          case 'float': return '%f';
          case 'string': return '%s';
          default: return '%d';
        }
      }

      // --- Funzione ricorsiva per generare il corpo del codice ---
      void generateCodeForNode(String nodeId, int indentation) {
        if (visitedNodes.contains(nodeId) || nodeId.isEmpty) return;
        visitedNodes.add(nodeId);

        final node = flowchart.nodes.firstWhere((n) => n.id == nodeId);
        final indent = '    ' * indentation;

        switch (node.kind) {
          case FlowNodeKind.input:
            final varName = (node.data?['targetVariables'] as List).first;
            final variable = flowchart.variables.firstWhere((v) => v.name == varName);
            code.writeln('${indent}// Nodo: ${node.text}');
            code.writeln('${indent}printf("Inserisci valore per ${variable.name}: ");');
            code.writeln('${indent}scanf("${mapTypeToFormatSpecifier(variable.dataType)}", &${variable.name});');
            break;

          case FlowNodeKind.output:
            String template = node.data?['template'] as String? ?? "";
            final varNames = (node.data?['variables'] as List?)?.cast<String>() ?? [];

            String cTemplate = template;
            if (varNames.isNotEmpty) {
              for (final varName in varNames) {
                // Trova la variabile per dedurne il tipo
                final variable = flowchart.variables.firstWhere(
                      (v) => v.name == varName,
                  orElse: () => VariableDeclaration(name: '', dataType: 'unknown', defaultValue: null),
                );
                // Sostituisce {nomeVar} con lo specificatore di formato corretto (%d, %f, %s)
                if (variable.dataType != 'unknown') {
                  cTemplate = cTemplate.replaceAll(
                      '{${variable.name}}', mapTypeToFormatSpecifier(variable.dataType));
                }
              }
            }

            code.writeln('${indent}// Nodo: ${node.text}');
            if (varNames.isEmpty) {
              // Se non ci sono variabili, stampa la stringa così com'è
              code.writeln('${indent}printf("$cTemplate\\n");');
            } else {
              // Altrimenti, costruisce il printf con la stringa di formato e gli argomenti
              code.writeln('${indent}printf("$cTemplate\\n", ${varNames.join(', ')});');
            }
            break;

          case FlowNodeKind.decision:
            final condition = node.data?['condition'] as String? ?? "1";
            final trueEdge = flowchart.edges.firstWhere((e) => e.from == node.id && e.port == 'true');
            final falseEdge = flowchart.edges.firstWhere((e) => e.from == node.id && e.port == 'false');

            code.writeln('${indent}// Nodo: ${node.text}');
            code.writeln('${indent}if ($condition) {');
            generateCodeForNode(trueEdge.to, indentation + 1);
            code.writeln('$indent} else {');
            generateCodeForNode(falseEdge.to, indentation + 1);
            code.writeln('$indent}');
            return;

          case FlowNodeKind.end:
            if (flowchart.name == 'main') {
              code.writeln('${indent}return 0;');
            } else if (flowchart.signature.returnType != 'void') {
              code.writeln('${indent}return 0; // Valore di ritorno di default');
            } else {
              code.writeln('${indent}return;');
            }
            return;

          default:
            code.writeln('${indent}// Nodo ${node.kind.name}: ${node.text}');
        }

        final nextEdge = flowchart.edges.firstWhere((e) => e.from == node.id, orElse: () => const EdgeEntity(from: '', to: '', port: null));
        generateCodeForNode(nextEdge.to, indentation);
      }

      // --- Inizio Costruzione Codice ---
      code.writeln('#include <stdio.h>');
      code.writeln();

      if (flowchart.name == 'main') {
        code.writeln('int main() {');
      } else {
        code.writeln('${mapDataType(flowchart.signature.returnType)} ${flowchart.name}() {');
      }

      if (flowchart.variables.isNotEmpty) {
        code.writeln('    // Dichiarazione delle variabili');
        for (var variable in flowchart.variables) {
          if (variable.dataType == 'string') {
            code.writeln('    char ${variable.name}[256];');
          } else {
            code.writeln('    ${mapDataType(variable.dataType)} ${variable.name} = ${variable.defaultValue};');
          }
        }
        code.writeln();
      }

      final startNode = flowchart.nodes.firstWhere((n) => n.kind == FlowNodeKind.start);
      final firstEdge = flowchart.edges.firstWhere((e) => e.from == startNode.id, orElse: () => const EdgeEntity(from: '', to: '', port: null));
      generateCodeForNode(firstEdge.to, 1);

      code.writeln('}');

      return code.toString();
    } catch (e) {
      return "Impossibile generare il codice C.\nErrore: ${e.toString()}";
    }
  }


  /// **HANDLER**
  Future<void> _onExecuteActiveFile(
      ExecuteActiveFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    emit(currentState.copyWith(isLoading: true));
    try {
      final liveContentStream =
      projectRepository.liveFileContent(event.projectId, event.fileId);
      final String? rtdbContent = await liveContentStream.first;

      final file = currentState.files.firstWhere((f) => f.fileId == event.fileId);
      final content = rtdbContent ?? file.content;

      final generatedCode = _generateCCode(content);

      emit(ShowExecutionJsonDialog(
          formattedJson: generatedCode, fileName: file.name));
      emit(currentState.copyWith(isLoading: false));
    } catch (e) {
      emit(currentState.copyWith(
          isLoading: false,
          error: 'Errore durante la generazione del codice: ${e.toString()}'));
    }
  }

  // ... (tutti gli altri metodi del BLoC rimangono invariati)
  Future<void> _onRefreshFileSystem(
      RefreshFileSystem event, Emitter<FileSystemState> emit) async {
    emit(const FileSystemLoading());
    try {
      final files = await projectRepository.getProjectFiles(projectId: event.projectId);
      final mainFile = files.firstWhere((f) => f.name.toLowerCase() == 'main', orElse: () => files.first);
      emit(FileSystemLoaded(files: files, activeFileId: mainFile.fileId));
    } catch (e) {
      emit(FileSystemError(message: 'Errore nel caricamento dei file: ${e.toString()}'));
    }
  }

  Future<void> _onCreateNewFile(
      CreateNewFile event, Emitter<FileSystemState> emit) async {
    if (state is! FileSystemLoaded) return;
    final currentState = state as FileSystemLoaded;

    final fileName = event.fileName.trim();

    if (fileName.isEmpty) {
      emit(currentState.copyWith(error: 'Il nome del file non può essere vuoto.'));
      return;
    }
    if (currentState.files.any((f) => f.name.toLowerCase() == fileName.toLowerCase())) {
      emit(currentState.copyWith(error: 'Un file con questo nome esiste già.'));
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
        return f.fileId == event.fileId ? MyFile(fileId: f.fileId, name: newName, content: f.content)
            : f;
      }).toList();

      emit(currentState.copyWith(files: updatedFiles, isLoading: false));
    } catch (e) {
      emit(currentState.copyWith(isLoading: false, error: 'Errore durante la rinomina.'));
    }
  }
}
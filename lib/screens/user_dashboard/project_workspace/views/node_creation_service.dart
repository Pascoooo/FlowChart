import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:file_repository/file_repository.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

/// Servizio centralizzato per la gestione della creazione di nodi nel flowchart.
/// Gestisce la logica di validazione, recupero variabili e apertura dei dialog.
class NodeCreationService {
  /// Gestisce l'intero processo di creazione di un nodo, inclusi i casi speciali
  /// come End (che chiede conferma se esiste già un nodo End).
  ///
  /// Ritorna i dati del nodo configurato dall'utente, o null se l'operazione è stata annullata.
  static Future<Map<String, dynamic>?> createNode({
    required BuildContext context,
    required FlowNodeKind kind,
    required String sourceNodeId,
    String? fromPort,
    BoxConstraints? canvasConstraints,
  }) async {
    final bloc = context.read<FlowchartBloc>();
    final flowState = bloc.state;

    if (flowState is! FlowchartLoaded) return null;

    // Caso speciale: End - verifica se esiste già e chiedi conferma
    if (kind == FlowNodeKind.end) {
      final shouldLink = await shouldLinkToExistingEnd(context, flowState);
      if (shouldLink) {
        bloc.add(LinkToExistingEnd(fromNodeId: sourceNodeId, fromPort: fromPort));
        return null;
      }

      // Se non esiste o l'utente ha rifiutato, continua con la creazione normale
      final hasEndNode = flowState.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end);
      if (hasEndNode) {
        // L'utente ha rifiutato di collegare al nodo esistente
        return null;
      }
    }

    // Prepara i dati del nodo (apre il dialog se necessario)
    final nodeData = await prepareNodeCreation(
      context: context,
      kind: kind,
      flowState: flowState,
      sourceNodeIds: {sourceNodeId},
    );

    return nodeData;
  }

  /// Gestisce la creazione di un nuovo nodo mostrando il dialog appropriato
  /// e raccogliendo le informazioni necessarie.
  ///
  /// Ritorna i dati del nodo configurato dall'utente, o null se l'operazione è stata annullata.
  static Future<Map<String, dynamic>?> prepareNodeCreation({
    required BuildContext context,
    required FlowNodeKind kind,
    required FlowchartLoaded flowState,
    Set<String>? sourceNodeIds,
  }) async {
    List<VariableDeclaration>? variablesForDialog;
    List<MyFile>? filesForProcess;

    switch (kind) {
      case FlowNodeKind.input:
        // NUOVA REGOLA: Non mostrare warning, passa lista vuota se necessario
        variablesForDialog = flowState.flowchart.variables
            .where((v) => v.scope == VariableScope.input)
            .toList();
        break;

      case FlowNodeKind.output:
        // NUOVA REGOLA: Non mostrare warning, passa lista vuota se necessario
        variablesForDialog = flowState.flowchart.variables
            .where((v) => v.scope == VariableScope.output)
            .toList();
        break;

      case FlowNodeKind.assignment:
        // NUOVA REGOLA: Ammette tutti i tipi di variabili, nessun filtro
        variablesForDialog = flowState.flowchart.variables.toList();
        break;

      case FlowNodeKind.decision:
      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
        // NUOVA REGOLA: Passa tutte le variabili disponibili senza filtri
        variablesForDialog = flowState.flowchart.variables.toList();
        break;

      case FlowNodeKind.process:
        final fsState = context.read<FileSystemBloc>().state;
        if (fsState is FileSystemLoaded) {
          filesForProcess = fsState.files
              .where((f) => f.fileId != fsState.activeFileId)
              .toList();
          // NUOVA REGOLA: Anche se la lista è vuota, passa comunque senza warning
        }
        break;


      case FlowNodeKind.end:
      case FlowNodeKind.start:
        // Nodi Start/End non richiedono configurazione
        return {'text': kind == FlowNodeKind.start ? 'Inizio' : 'Fine'};
    }

    // Apri il dialog di configurazione del nodo
    return await AppDialogs.showNodeCreationDialog(
      context: context,
      kind: kind,
      files: filesForProcess,
      variables: variablesForDialog,
    );
  }

  /// Verifica se esiste già un nodo End e chiede conferma per collegarvisi.
  /// Ritorna true se l'utente vuole collegare al nodo End esistente.
  static Future<bool> shouldLinkToExistingEnd(
    BuildContext context,
    FlowchartLoaded flowState,
  ) async {
    final hasEndNode = flowState.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end);

    if (!hasEndNode) {
      return false;
    }

    final bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Collega al nodo "Fine"',
      message: 'Esiste già un nodo di fine nel flowchart. Vuoi collegare questo nodo al "Fine" esistente?',
      confirmText: 'Collega',
      cancelText: 'Annulla',
    );

    return confirmed == true;
  }
}

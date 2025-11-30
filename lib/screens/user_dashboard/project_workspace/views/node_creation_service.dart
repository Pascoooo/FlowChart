import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:file_repository/file_repository.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';

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

    // VALIDAZIONE: Nodi Start/End sono ammessi SOLO nel file main
    if (kind == FlowNodeKind.start || kind == FlowNodeKind.end) {
      final fileName = flowState.flowchart.name.toLowerCase();
      if (fileName != 'main') {
        await AppDialogs.showInfoDialog(
          context,
          title: 'Operazione non permessa',
          message: 'I blocchi "Inizio" e "Fine" possono essere inseriti solo nel file "main".\n\n'
                  'I file funzione non richiedono questi blocchi.',
          type: DialogType.warning,
        );
        return null;
      }
    }

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
        // NUOVA REGOLA: Input può assegnare valori a variabili input E params
        variablesForDialog = flowState.flowchart.variables
            .where((v) => v.scope == VariableScope.input || v.scope == VariableScope.params)
            .toList();
        break;

      case FlowNodeKind.output:
        // NUOVA REGOLA: Output può stampare variabili output E params
        variablesForDialog = flowState.flowchart.variables
            .where((v) => v.scope == VariableScope.output || v.scope == VariableScope.params)
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
        // NUOVA REGOLA: Non mostrare warning, passa lista vuota se necessario
        // I file vengono recuperati dal FileSystemBloc
        final fileSystemState = context.read<FileSystemBloc>().state;
        if (fileSystemState is FileSystemLoaded) {
          filesForProcess = fileSystemState.files;
        }
        variablesForDialog = flowState.flowchart.variables.toList();
        break;

      case FlowNodeKind.start:
      case FlowNodeKind.end:
      case FlowNodeKind.doWhileStart:
        // Questi nodi non richiedono variabili o files
        break;

      case FlowNodeKind.functionHeader:
        // Il nodo FunctionHeader non dovrebbe essere creabile manualmente
        // Viene generato automaticamente quando si crea un sottoprogramma
        return null;

      case FlowNodeKind.returnNode:
        // Il nodo Return può usare tutte le variabili disponibili
        variablesForDialog = flowState.flowchart.variables.toList();
        break;
    }

    // Apre il dialogo di creazione/modifica e attende i dati di ritorno.
    final nodeData = await AppDialogs.showNodeCreationDialog(
      context: context,
      kind: kind,
      signature: flowState.flowchart.signature, // REQUISITO: Passa la signature
      files: filesForProcess,
      variables: variablesForDialog,
    );

    // REQUISITO: Se il dialogo ha creato una nuova variabile, aggiungila al flowchart
    if (nodeData != null && nodeData['newVariable'] != null) {
      context.read<FlowchartBloc>().add(AddGlobalVariable(nodeData['newVariable']));
    }

    return nodeData;
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

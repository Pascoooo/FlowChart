import 'dart:typed_data';
import 'package:flowchart_thesis/config/services/dialog_service/service_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../banner_service.dart';
import 'node_dialogs/declaration_dialogs/add_declared_variable.dart';
import 'node_dialogs/declaration_dialogs/edit_variable_dialog.dart';
import 'recovery_dialogs.dart';
import 'share_dialogs.dart';
import 'node_dialogs/decision_node_dialog.dart';
import 'node_dialogs/info_node_dialog.dart' as node_info;
import 'node_dialogs/input_node_dialog.dart';
import 'node_dialogs/output_node_dialog.dart';
import 'node_dialogs/process_node_dialog.dart';
import 'node_dialogs/assignment_node_dialog.dart';
import 'node_dialogs/return_node_dialog.dart';

class AppDialogs {

  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        bool isDestructive = false,
      }) {
    return GenericDialogs.showConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
  }

  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        String? message,
        String? initialValue,
        String hintText = '',
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        required String? Function(String?)? validator,
        required String inputLabel,
      }) {
    return GenericDialogs.showInputDialog(
        context,
        title: title,
        message: message,
        initialValue: initialValue,
        hintText: hintText,
        confirmText: confirmText,
        cancelText: cancelText,
        validator: validator,
        inputLabel: inputLabel
    );
  }

  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        required String message,
        DialogType type = DialogType.info,
        String closeText = 'Ho capito',
      }) {
    return GenericDialogs.showInfoDialog(
      context,
      title: title,
      message: message,
      type: type,
      closeText: closeText,
    );
  }

  /// Mostra un dialogo per scegliere tra il reset del solo canvas o di tutto.
  static Future<ResetChoice?> showResetOptionsDialog(
      BuildContext context, {
        required String title,
        required String message,
      }) {
    // Questo metodo chiama il dialogo generico con i testi specifici.
    return GenericDialogs.showResetOptionsDialog(
      context,
      title: title,
      message: message,
      cancelText: 'Annulla',
      canvasOnlyText: 'Resetta solo i nodi',
      everythingText: 'Resetta anche variabili',
    );
  }


  /// Mostra un dialogo per creare una nuova variabile globale.
  static Future<VariableDeclaration?> showAddVariableDialog({
    required BuildContext context,
    required VariableScope scope,
    required Set<String> existingVariableNames,
  }) {
    return showDialog<VariableDeclaration>(
      context: context,
      builder: (_) => AddVariableDialog(
        scope: scope,
        existingVariableNames: existingVariableNames,
      ),
    );
  }

  /// Mostra un dialogo per modificare una variabile globale esistente.
  static Future<Map<String, dynamic>?> showEditVariableDialog({
    required BuildContext context,
    required VariableDeclaration variableToEdit,
    required Set<String> existingVariableNames,
    bool canEditType = true,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => EditVariableDialog(
        variableToEdit: variableToEdit,
        existingVariableNames: existingVariableNames,
        canEditType: canEditType,
      ),
    );
  }


  // --- Dialoghi per Editor Nodi ---

  static Future<Map<String, dynamic>?> showNodeCreationDialog({
    required BuildContext context,
    required FlowNodeKind kind,
    List<MyFile>? files,
    List<VariableDeclaration>? variables,
    Set<String>? existingVariableNames,
  }) {
    switch (kind) {
      case FlowNodeKind.input:
        return showInputNodeDialog(context,availableInputVariables: variables ?? const [],);

      case FlowNodeKind.assignment:
        return showAssignmentNodeDialog(
          context,
          availableVariables: variables ?? const [],
        );

      case FlowNodeKind.output:
        return showOutputNodeDialog(context, availableVariables: variables ?? const []);

      case FlowNodeKind.process:
        // NUOVA REGOLA: Apri il dialog anche se la lista è vuota, senza warning
        return showProcessNodeDialog(
          context,
          files: files ?? const <MyFile>[],
          availableVariables: variables ?? const <VariableDeclaration>[],
        );

      case FlowNodeKind.decision:
      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
        // Usa lo stesso dialog per Decision, While e DoWhile (tutti gestiscono condizioni)
        final vars = variables ?? const [];
        final decisionVars = vars
            .map((v) => {'name': v.name, 'type': v.dataType})
            .toList();
        return showDecisionNodeDialog(context, variables: decisionVars);

      case FlowNodeKind.start:
        return Future.value({'text': 'Inizio'});

      case FlowNodeKind.end:
        return Future.value({'text': 'Fine'});

      case FlowNodeKind.doWhileStart:
        // Nodo sentinella usato internamente per il corpo del do-while: nessun dialog richiesto
        return Future.value({'text': 'doWhileStart'});

      case FlowNodeKind.functionHeader:
        // Il nodo FunctionHeader viene creato automaticamente quando si crea un sottoprogramma
        // Non dovrebbe essere creabile manualmente dall'utente
        return Future.value(null);

      case FlowNodeKind.returnNode:
        // Dialog per configurare il nodo Return (espressione di ritorno)
        return showReturnNodeDialog(context, availableVariables: variables ?? const []);
    }
  }

  static Future<void> showNodeDetailsDialog({
    required BuildContext context,
    required FlowNode node,
  }) {
    return node_info.showNodeDetailsDialog(context: context, node: node);
  }


  static Future<void> showExportLocationDialog({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
  }) {
    return ShareDialogs.showExportLocationDialog(
      context: context,
      pngBytes: pngBytes,
      fileName: fileName,
    );
  }

  static Future<void> showAdvancedShareDialog({
    required BuildContext context,
    required MyProject project,
    required VoidCallback onMakePublic,
  }) {
    return ShareDialogs.showAdvancedShareDialog(
      context: context,
      project: project,
      onMakePublic: onMakePublic,
    );
  }

  static Future<void> showShareInfoDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String copyableText,
  }) {
    return ShareDialogs.showInfoWithCopyableText(
      context: context,
      title: title,
      message: message,
      copyableText: copyableText,
    );
  }

  // --- Dialoghi di Recupero Sessione ---

  static Future<RecoveryAction?> showInitialRecoveryDialog({
    required BuildContext context,
    required String projectName,
  }) {
    return RecoveryDialogs.showInitialRecoveryDialog(
      context: context,
      projectName: projectName,
    );
  }

  static Future<bool?> showManualRecoveryDialog({
    required BuildContext context,
    required UnsavedChangesFound state,
  }) {
    return RecoveryDialogs.showManualRecoveryDialog(
      context: context,
      state: state,
    );
  }

  static void showSuccessBanner(BuildContext context, String message) {
    BannerService.showSuccess(context, message);
  }
}

import 'dart:typed_data';

import 'package:flowchart_thesis/config/services/dialog_service/service_dialog.dart';
import 'package:flutter/material.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../banner_service.dart';
import 'recovery_dialogs.dart';
import 'share_dialogs.dart';
import 'node_dialogs/decision_node_dialog.dart';
import 'node_dialogs/info_node_dialog.dart' as node_info;
import 'node_dialogs/input_node_dialog.dart';
import 'node_dialogs/output_node_dialog.dart';
import 'node_dialogs/process_node_dialog.dart';


class AppDialogs {
  // --- Dialoghi Generici ---

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
      // --- Passa i nomi esistenti al dialogo di input ---
        return showInputNodeDialog(
          context,
          existingVariableNames: existingVariableNames ?? const {},
        );

      case FlowNodeKind.output:
        return showOutputNodeDialog(context, availableVariables: variables ?? const []);

      case FlowNodeKind.process:
        final fileOptions = files ?? const <MyFile>[];
        if (fileOptions.isEmpty) {
          return showInfoDialog(
            context,
            title: 'Nessun file disponibile',
            message:
            'Non è possibile creare un nodo Processo perché non ci sono file nel programma.\n'
                'Aggiungi prima un file e riprova.',
            type: DialogType.warning,
          ).then((_) => null);
        }

        return showProcessNodeDialog(
          context,
          files: fileOptions,
          availableVariables: variables ?? const <VariableDeclaration>[],
        );


      case FlowNodeKind.decision:
        final vars = variables ?? const [];
        if (vars.isEmpty) {
          return showInfoDialog(
            context,
            title: 'Nessuna variabile disponibile',
            message:
                'Non è possibile creare una condizione perché non ci sono variabili nel programma.\n'
                'Aggiungi prima una variabile (es. con un nodo Input o Processo) e riprova.',
            type: DialogType.warning,
          ).then((_) => null);
        }
        final decisionVars = vars
            .map((v) => {'name': v.name, 'type': v.dataType})
            .toList();
        return showDecisionNodeDialog(context, variables: decisionVars);

      case FlowNodeKind.start:
        return Future.value({'text': 'Inizio'});

      case FlowNodeKind.end:
        return Future.value({'text': 'Fine'});
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

  // --- Banner e Notifiche (delegato a BannerService) ---

  static void showSuccessBanner(BuildContext context, String message) {
    BannerService.showSuccess(context, message);
  }
}
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

  /// Mostra un dialogo di conferma generico (Sì/No).
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        // --- FIX: Ripristinati i parametri opzionali che erano stati omessi ---
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        bool isDestructive = false,
      }) {
    return GenericDialogs.showConfirmationDialog(
      context,
      title: title,
      message: message,
      // --- FIX: I parametri ora vengono passati correttamente al metodo sottostante ---
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
  }

  /// Mostra un dialogo per l'inserimento di testo.
  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        String? message,
        String? initialValue,
        // --- FIX: Ripristinati i parametri opzionali che erano stati omessi ---
        String hintText = '',
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        String? Function(String?)? validator,
      }) {
    return GenericDialogs.showInputDialog(
      context,
      title: title,
      message: message,
      initialValue: initialValue,
      // --- FIX: I parametri ora vengono passati correttamente al metodo sottostante ---
      hintText: hintText,
      confirmText: confirmText,
      cancelText: cancelText,
      validator: validator,
    );
  }

  /// Mostra un dialogo informativo usando un tipo predefinito per stile e icona.
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
    List<Map<String, String>>? variables,
  }) {
    switch (kind) {
      case FlowNodeKind.input:
        return showInputNodeDialog(context);
      case FlowNodeKind.output:
        return showOutputNodeDialog(context);
      case FlowNodeKind.process:
        return showProcessNodeDialog(context, files: files ?? const []);
      case FlowNodeKind.decision:
        return showDecisionNodeDialog(context, variables: variables ?? const []);
      case FlowNodeKind.start:
        return Future.value({'text': 'Inizio'});
      case FlowNodeKind.end:
        return Future.value({'text': 'Fine'});
    }
  }

  static Future<void> showNodeDetailsDialog({
    required BuildContext context,
    required FlowNode node,
  }) async {
    // return node_info.showNodeDetailsDialog(context: context, node: node);
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
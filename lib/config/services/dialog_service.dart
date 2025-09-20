// lib/config/services/dialog_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import '../../blocs/auth_bloc/authentication_bloc.dart';
import '../../blocs/auth_bloc/authentication_event.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../screens/settings/widgets/settings_provider.dart';
import '../../screens/user_dashboard/project_selection/widgets/flowchart_preview.dart';
import 'export_service.dart';

// Enum per gestire il risultato del dialogo in modo pulito
enum RecoveryAction { recoverAll, discardAll, manualSelect, cancelled }

/// **Servizio per la Gestione di Dialoghi Nativi in stile Cupertino**
class DialogService {
  /// Mostra il dialogo di recupero sessione e restituisce l'azione dell'utente.
  static Future<RecoveryAction?> showInitialRecoveryDialog({
    required BuildContext context,
    required String projectName,
  }) {
    return showCupertinoDialog<RecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('Recupero Sessione per "$projectName"'),
          content: const Text(
              "Sono state trovate modifiche non salvate in uno o più file. Come vuoi procedere?"),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(RecoveryAction.recoverAll),
              isDefaultAction: true,
              child: const Text("Recupera tutti"),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(RecoveryAction.manualSelect),
              child: const Text("Scegli manualmente"),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(RecoveryAction.discardAll),
              isDestructiveAction: true,
              child: const Text("Scarta tutti"),
            ),
          ],
        );
      },
    );
  }

  /// Mostra il dialogo di recupero manuale con anteprime visive.
  static Future<bool?> showManualRecoveryDialog({
    required BuildContext context,
    required UnsavedChangesFound state,
  }) {
    final projectBloc = context.read<ProjectBloc>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: projectBloc,
        child: _ManualRecoveryDialog(state: state),
      ),
    );
  }

  /// Mostra un dialogo informativo di base in stile Cupertino.
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        String? message,
        IconData? icon,
        Color? iconColor,
        String closeText = 'OK',
      }) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              const SizedBox(height: 12),
              Icon(icon,
                  size: 48,
                  color: iconColor ??
                      CupertinoDynamicColor.resolve(
                          CupertinoColors.label, dialogContext)),
              const SizedBox(height: 8),
            ],
            if (message != null) Text(message),
          ],
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(closeText),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialogo di conferma (sì/no) in stile Cupertino.
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
      }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Dialogo con campo di input (invariato).
  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        String? message,
        String? initialValue,
        String hintText = '',
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        String? Function(String?)? validator,
      }) async {
    final controller = TextEditingController(text: initialValue);
    final theme = Theme.of(context);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        var isInitialCheck = true;
        return StatefulBuilder(
          builder: (context, setState) {
            String? errorText;
            bool isButtonEnabled = false;
            void validate(String value) {
              if (validator != null) {
                errorText = validator(value);
                isButtonEnabled = errorText == null;
              } else {
                isButtonEnabled = value.trim().isNotEmpty;
              }
            }
            validate(controller.text);
            final bool isDuplicateNameError = errorText == 'Nome già in uso';
            return Dialog(
              elevation: 0,
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Column(
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 4),
                            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                          ],
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            controller: controller,
                            autofocus: true,
                            placeholder: hintText,
                            style: theme.textTheme.bodyMedium,
                            onChanged: (value) {
                              if (isInitialCheck) isInitialCheck = false;
                              setState(() => validate(value));
                            },
                          ),
                          Container(
                            height: 24,
                            padding: const EdgeInsets.only(top: 8.0),
                            alignment: Alignment.center,
                            child: (errorText != null && !(isInitialCheck && isDuplicateNameError))
                                ? Text(
                              errorText!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              textAlign: TextAlign.center,
                            )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              child: Text(cancelText, style: TextStyle(color: theme.colorScheme.primary)),
                            ),
                          ),
                          VerticalDivider(width: 1, color: theme.dividerColor),
                          Expanded(
                            child: CupertinoButton(
                              onPressed: isButtonEnabled ? () => Navigator.of(context).pop(controller.text.trim()) : null,
                              child: Text(
                                confirmText,
                                style: TextStyle(
                                  color: isButtonEnabled ? theme.colorScheme.primary : theme.disabledColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Mostra il dialogo per la scelta della destinazione di esportazione.
  static Future<void> showExportLocationDialog({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
  }) {
    void handleExport(BuildContext dialogContext, ExportPreference choice,
        bool shouldRemember) {
      if (shouldRemember) {
        dialogContext.read<SettingsProvider>().updateExportPreference(choice);
      }
      Navigator.of(dialogContext).pop();

      if (choice == ExportPreference.local) {
        ExportService.downloadFileWithDialog(
            context: context, bytes: pngBytes, fileName: fileName);
      } else if (choice == ExportPreference.drive) {
        context.read<AuthenticationBloc>().add(
          ExportFlowchartToDriveRequested(
              fileName: '$fileName.png', fileBytes: pngBytes),
        );
      }
    }

    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final isDriveConnected =
            dialogContext.watch<AuthenticationBloc>().state.user.driveConnected;
        bool rememberChoice = false;

        final TextStyle bodyTextStyle =
            CupertinoTheme.of(dialogContext).textTheme.textStyle;

        final TextStyle cancelActionStyle = bodyTextStyle.copyWith(
          color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel, dialogContext),
        );

        return StatefulBuilder(builder: (context, setState) {
          return CupertinoAlertDialog(
            title: const Text('Salva Esportazione'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  const Text('Scegli dove salvare il diagramma.'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildExportOptionButton(
                        context: context,
                        icon: FontAwesomeIcons.computer,
                        label: 'Dispositivo',
                        onTap: () => handleExport(dialogContext,
                            ExportPreference.local, rememberChoice),
                      ),
                      _buildExportOptionButton(
                        context: context,
                        icon: FontAwesomeIcons.googleDrive,
                        label: 'Google Drive',
                        isEnabled: isDriveConnected,
                        onTap: () => handleExport(dialogContext,
                            ExportPreference.drive, rememberChoice),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildRememberChoiceCheckbox(
                    context: context,
                    value: rememberChoice,
                    textStyle: bodyTextStyle,
                    onChanged: (newValue) {
                      setState(() => rememberChoice = newValue);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Annulla', style: cancelActionStyle),
              ),
            ],
          );
        });
      },
    );
  }

  /// Helper per costruire i pulsanti di opzione.
  static Widget _buildExportOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    final activeColor =
    CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);
    final inactiveColor =
    CupertinoDynamicColor.resolve(CupertinoColors.inactiveGray, context);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: isEnabled ? onTap : null,
        child: Column(
          children: [
            Icon(icon, size: 32, color: isEnabled ? activeColor : inactiveColor),
            const SizedBox(height: 8),
            Text(label,
                style:
                TextStyle(color: isEnabled ? activeColor : inactiveColor)),
          ],
        ),
      ),
    );
  }

  /// Helper per costruire la checkbox "Ricorda la mia scelta".
  static Widget _buildRememberChoiceCheckbox({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TextStyle textStyle,
  }) {
    final secondaryLabelColor =
    CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final activeColor =
    CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);
    final borderColor =
    CupertinoDynamicColor.resolve(CupertinoColors.placeholderText, context);

    const double boxSize = 18.0;
    const double iconSize = 12.0;

    Widget checkboxWidget = Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuad,
        scale: value ? 1.0 : 0.0,
        child: Icon(
          FontAwesomeIcons.check,
          color: activeColor,
          size: iconSize,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              checkboxWidget,
              const SizedBox(width: 12),
              Text('Ricorda la mia scelta', style: textStyle),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: value
              ? Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Potrai cambiarlo dalle impostazioni.',
              textAlign: TextAlign.center,
              style:
              TextStyle(fontSize: 12, color: secondaryLabelColor),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// --- WIDGET PRIVATI PER IL RECUPERO MANUALE ---

class _ManualRecoveryDialog extends StatefulWidget {
  final UnsavedChangesFound state;
  const _ManualRecoveryDialog({required this.state});

  @override
  State<_ManualRecoveryDialog> createState() => _ManualRecoveryDialogState();
}

class _ManualRecoveryDialogState extends State<_ManualRecoveryDialog> {
  late List<UnsavedFileChange> _remainingFiles;

  @override
  void initState() {
    super.initState();
    _remainingFiles = List.from(widget.state.changedFiles);
  }

  void _handleDecision() {
    setState(() {
      if (_remainingFiles.isNotEmpty) {
        _remainingFiles.removeAt(0);
      }
      if (_remainingFiles.isEmpty) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingFiles.isEmpty) {
      return const SizedBox.shrink();
    }
    final currentFile = _remainingFiles.first;
    final totalFiles = widget.state.changedFiles.length;
    final processedCount = totalFiles - _remainingFiles.length + 1;
    final title =
        '${widget.state.projectName} - File: "${currentFile.fileName}" ($processedCount/$totalFiles)';

    void onDiscard() {
      context.read<ProjectBloc>().add(DiscardSingleFileChange(
        projectId: widget.state.projectId,
        fileId: currentFile.fileId,
      ));
      _handleDecision();
    }

    void onRecover() {
      context.read<ProjectBloc>().add(RecoverSingleFile(
        projectId: widget.state.projectId,
        fileId: currentFile.fileId,
        rtdbContent: currentFile.rtdbContent,
      ));
      _handleDecision();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      backgroundColor: CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context),
      child: _MegaRecoveryDialogLayout(
        key: ValueKey(currentFile.fileId),
        title: title,
        firestoreContent: currentFile.firestoreContent,
        rtdbContent: currentFile.rtdbContent,
        onKeepSaved: onDiscard,
        onRecoverLocal: onRecover,
      ),
    );
  }
}

/// Layout personalizzato in stile Cupertino per il dialogo di recupero con anteprime.
class _MegaRecoveryDialogLayout extends StatelessWidget {
  final String title;
  final String firestoreContent;
  final String rtdbContent;
  final VoidCallback onKeepSaved;
  final VoidCallback onRecoverLocal;

  const _MegaRecoveryDialogLayout({
    super.key,
    required this.title,
    required this.firestoreContent,
    required this.rtdbContent,
    required this.onKeepSaved,
    required this.onRecoverLocal,
  });

  @override
  Widget build(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final dialogWidth = MediaQuery.of(context).size.width * 0.85;
    final dialogHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: cupertinoTheme.textTheme.navLargeTitleTextStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "Scegli quale versione del file desideri conservare.",
            style: cupertinoTheme.textTheme.textStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildPreviewColumn(
                  context,
                  title: "Versione Salvata",
                  subtitle: "(Questa versione è al sicuro nel cloud)",
                  content: firestoreContent,
                ),
                const VerticalDivider(width: 32, thickness: 1),
                _buildPreviewColumn(
                  context,
                  title: "Modifiche Locali",
                  subtitle: "(Non salvate, da una sessione precedente)",
                  content: rtdbContent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: onKeepSaved,
                  child: const Text("Conserva Versione Salvata"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: onRecoverLocal,
                  child: const Text("Recupera Modifiche Locali"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewColumn(BuildContext context, {
    required String title,
    required String subtitle,
    required String content,
  }) {
    final cupertinoTheme = CupertinoTheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(title, style: cupertinoTheme.textTheme.navTitleTextStyle),
          Text(subtitle, style: cupertinoTheme.textTheme.tabLabelTextStyle),
          const SizedBox(height: 8),
          Expanded(
            child: FlowchartPreview(flowchartContent: content),
          ),
        ],
      ),
    );
  }
}
// lib/config/services/dialog_service.dart
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../blocs/auth_bloc/authentication_bloc.dart';
import '../../blocs/auth_bloc/authentication_event.dart';
import '../../screens/settings/widgets/settings_provider.dart';
import 'export_service.dart';

/// **Servizio per la Gestione di Dialoghi Nativi**
///
/// Questa classe fornisce metodi statici per mostrare dialoghi modali con un'estetica
/// nativa iOS, utilizzando i widget di Cupertino e garantendo un'esperienza utente
/// coerente e professionale.
class DialogService {
  /// Mostra un dialogo informativo di base in stile Cupertino.
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        String? message,
        IconData? icon,
        Color? iconColor,
        String closeText = 'OK',
      }) {
    // Utilizza il metodo base per la costruzione del dialogo.
    return _showBaseCupertinoDialog<void>(
      context: context,
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            const SizedBox(height: 12),
            Icon(icon,
                size: 48,
                color: iconColor ??
                    CupertinoDynamicColor.resolve(
                        CupertinoColors.label, context)),
            const SizedBox(height: 8),
          ],
          if (message != null) Text(message),
        ],
      ),
      actions: [
        // Azione di chiusura di default.
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(closeText),
        ),
      ],
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
    // Utilizza il metodo base per la costruzione del dialogo.
    return _showBaseCupertinoDialog<bool>(
      context: context,
      title: title,
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          isDestructiveAction: true, // Stile rosso per azioni distruttive.
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Dialogo con campo di input (invariato come da richiesta).
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


  /// **Dialogo di Esportazione (Refactored)**
  /// Mostra un dialogo modale centrato per scegliere la destinazione del file.
  /// L'interfaccia è pulita, professionale e si integra perfettamente con l'estetica iOS.
  static Future<void> showExportLocationDialog({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
  }) {
    // Funzione interna per gestire la logica di esportazione e chiusura del dialogo.
    void handleExport(BuildContext dialogContext, ExportPreference choice,
        bool shouldRemember) {
      if (shouldRemember) {
        // Salva la preferenza se l'utente ha spuntato la checkbox.
        dialogContext.read<SettingsProvider>().updateExportPreference(choice);
      }
      Navigator.of(dialogContext).pop(); // Chiude il dialogo.

      // Avvia l'azione di esportazione scelta.
      if (choice == ExportPreference.local) {
        ExportService.downloadFileWithDialog(
            context: context, bytes: pngBytes, fileName: fileName);
      } else if (choice == ExportPreference.drive) {
        context.read<AuthenticationBloc>().add(
          ExportFlowchartToDriveRequested(
              fileName: '${fileName}.png', fileBytes: pngBytes),
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

        // StatefulBuilder è ideale per gestire lo stato locale (la checkbox)
        // senza dover creare un intero StatefulWidget.
        return StatefulBuilder(builder: (context, setState) {
          return CupertinoAlertDialog(
            title: const Text('Salva Esportazione'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Text('Scegli dove salvare il diagramma.'),
                const SizedBox(height: 20),
                // Layout orizzontale per le opzioni di salvataggio.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildExportOptionButton(
                      context: context,
                      icon: FontAwesomeIcons.computer,
                      label: 'Dispositivo',
                      onTap: () => handleExport(
                          dialogContext, ExportPreference.local, rememberChoice),
                    ),
                    _buildExportOptionButton(
                      context: context,
                      icon: FontAwesomeIcons.googleDrive,
                      label: 'Google Drive',
                      isEnabled: isDriveConnected,
                      onTap: () => handleExport(
                          dialogContext, ExportPreference.drive, rememberChoice),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Widget per la checkbox "Ricorda la mia scelta".
                _buildRememberChoiceCheckbox(
                  context: context,
                  value: rememberChoice,
                  onChanged: (newValue) {
                    setState(() => rememberChoice = newValue);
                  },
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annulla'),
              ),
            ],
          );
        });
      },
    );
  }

  /// **Metodo Base Privato (DRY)**
  /// Centralizza la logica per mostrare un `CupertinoAlertDialog`,
  /// riducendo la duplicazione del codice.
  static Future<T?> _showBaseCupertinoDialog<T>({
    required BuildContext context,
    required String title,
    Widget? content,
    List<CupertinoDialogAction> actions = const [],
  }) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: content,
        actions: actions,
      ),
    );
  }

  /// Helper per costruire i pulsanti di opzione del dialogo di esportazione.
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
            Text(label, style: TextStyle(color: isEnabled ? activeColor : inactiveColor)),
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
  }) {
    final secondaryLabelColor = CupertinoDynamicColor.resolve(
        CupertinoColors.secondaryLabel, context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rende l'intera riga cliccabile per una migliore UX.
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Checkbox personalizzata in stile iOS.
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: value,
                      onChanged: (v) => onChanged(v ?? false),
                      activeColor: CupertinoColors.activeGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Ricorda la mia scelta'),
              ],
            ),
          ),
        ),
        // Messaggio informativo che appare con un'animazione.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: value
              ? Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Potrai cambiarlo dalle impostazioni.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: secondaryLabelColor),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
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
class DialogService {
  /// **RIPRISTINATO**: Mostra un dialogo informativo di base in stile Cupertino.
  /// La funzione è stata riportata alla sua versione originale per evitare
  /// qualsiasi effetto collaterale non desiderato.
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
      builder: (context) => CupertinoAlertDialog(
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
                          CupertinoColors.label, context)),
              const SizedBox(height: 8),
            ],
            if (message != null) Text(message),
          ],
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(closeText),
          ),
        ],
      ),
    );
  }

  /// **RIPRISTINATO**: Mostra un dialogo di conferma (sì/no) in stile Cupertino.
  /// La funzione è stata riportata alla sua versione originale per garantire
  /// il corretto funzionamento dei valori booleani di ritorno.
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
      }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
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

        // --- INIZIO MODIFICHE ---

        // 1. Otteniamo lo stile del testo di base dal tema per garantire coerenza.
        final TextStyle bodyTextStyle = CupertinoTheme.of(dialogContext).textTheme.textStyle;

        // 2. Creiamo uno stile specifico per l'azione "Annulla" partendo
        //    da quello di base, ma usando un colore grigio dipendente dal tema.
        final TextStyle cancelActionStyle = bodyTextStyle.copyWith(
          color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, dialogContext),
        );

        // --- FINE MODIFICHE ---

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
                    // 3. Passiamo lo stile del testo di base al nostro helper.
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
                onPressed: () => Navigator.of(context).pop(),
                // 4. Applichiamo lo stile personalizzato al testo "Annulla".
                child: Text('Annulla', style: cancelActionStyle),
              ),
            ],
          );
        });
      },
    );
  }

  /// Helper per i pulsanti di opzione.
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

    // --- INIZIO MODIFICHE ---

    // 1. Definiamo dimensioni più piccole per il riquadro e l'icona.
    const double boxSize = 18.0;
    const double iconSize = 12.0;

    // 2. Creiamo un singolo widget per la checkbox.
    //    Il bordo è sempre visibile e l'icona interna viene animata.
    Widget checkboxWidget = Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5), // Raggio leggermente ridotto
        border: Border.all(color: borderColor, width: 1.5),
      ),
      // L'animazione ora si applica solo all'icona interna
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuad,
        scale: value ? 1.0 : 0.0, // Appare se 'value' è true, scompare se false
        child: Icon(
          FontAwesomeIcons.check,
          color: activeColor,
          size: iconSize, // Usa la dimensione ridotta per l'icona
        ),
      ),
    );

    // --- FINE MODIFICHE ---

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3. Usiamo il nostro nuovo widget al posto di AnimatedSwitcher.
                checkboxWidget,
                const SizedBox(width: 12),
                Text('Ricorda la mia scelta', style: textStyle),
              ],
            ),
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
              style: TextStyle(fontSize: 12, color: secondaryLabelColor),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
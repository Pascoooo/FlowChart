import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Un servizio di utilità per mostrare dialoghi modali professionali
/// che si adattano al tema Material (light/dark) dell'applicazione.
class DialogService {
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    String? message,
    IconData? icon,
    Color? iconColor,
    String closeText = 'OK',
  }) async {
    final theme = Theme.of(context);

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
                  color: iconColor ?? theme.textTheme.bodySmall?.color),
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

  /// Mostra un dialogo di conferma in stile nativo (Cupertino).
  /// Questa funzione si adatta già bene ai temi e non necessita di modifiche.
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Conferma',
    String cancelText = 'Annulla',
  }) async {
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

  /// Mostra un dialogo di input non scrollabile ma con un aspetto Cupertino,
  /// completamente stilizzato usando il tema Material corrente.
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0)),
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
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            controller: controller,
                            autofocus: true,
                            placeholder: hintText,
                            style: theme.textTheme
                                .bodyMedium, // Stile del testo dal tema
                            onChanged: (value) {
                              if (isInitialCheck) isInitialCheck = false;
                              setState(() => validate(value));
                            },
                          ),
                          Container(
                            height: 24,
                            padding: const EdgeInsets.only(top: 8.0),
                            alignment: Alignment.center,
                            child: (errorText != null &&
                                    !(isInitialCheck && isDuplicateNameError))
                                ? Text(
                                    errorText!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.error),
                                    textAlign: TextAlign.center,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                        height: 1,
                        color:
                            theme.dividerColor), // Colore del divisore dal tema
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              child: Text(cancelText,
                                  style: TextStyle(
                                      color: theme.colorScheme.primary)),
                            ),
                          ),
                          VerticalDivider(width: 1, color: theme.dividerColor),
                          Expanded(
                            child: CupertinoButton(
                              onPressed: isButtonEnabled
                                  ? () => Navigator.of(context)
                                      .pop(controller.text.trim())
                                  : null,
                              child: Text(
                                confirmText,
                                style: TextStyle(
                                  color: isButtonEnabled
                                      ? theme.colorScheme.primary
                                      : theme.disabledColor,
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
}

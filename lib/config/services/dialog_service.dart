import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DialogService {
  /// Mostra un dialogo centrato; il builder riceve il context del dialogo
  /// così che tutte le chiamate a Navigator.pop usino la rotta del dialogo.
  static Future<T?> _showCenteredDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Builder(builder: (inner) => builder(inner)),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  /// Mostra un dialogo con un indicatore di caricamento.
  static Future<void> showLoadingDialog(
      BuildContext context, {
        required String message,
        bool barrierDismissible = false,
      }) {
    return _showCenteredDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Mostra un dialogo di conferma con due opzioni.
  /// Restituisce `true` se l'utente conferma, `false` se annulla, `null` se il
  /// dialogo viene ignorato.
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String cancelText = 'Annulla',
        String confirmText = 'Conferma',
        VoidCallback? onConfirm,
      }) {
    return _showCenteredDialog<bool?>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              // Chiudi il dialogo usando il context locale, poi esegui la callback
              Navigator.pop(dialogContext, true);
              WidgetsBinding.instance.addPostFrameCallback((_) => onConfirm?.call());
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialogo informativo con un titolo, un'icona e un contenuto.
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        required Widget content,
        IconData? icon,
        bool isFontAwesome = false,
        String okText = 'OK',
      }) {
    return _showCenteredDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: icon != null
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isFontAwesome
                ? FaIcon(icon, color: Theme.of(dialogContext).colorScheme.primary)
                : Icon(icon, color: Theme.of(dialogContext).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
            ),
          ],
        )
            : Text(
          title,
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
        ),
        content: content,
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialogo con un campo di testo per l'input.
  /// Restituisce la stringa inserita o `null` se il dialogo viene annullato.
  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        String? message,
        String? hintText,
        String? initialValue,
        String cancelText = 'Annulla',
        String confirmText = 'Conferma',
      }) {
    final controller = TextEditingController(text: initialValue);

    return _showCenteredDialog<String?>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message),
              const SizedBox(height: 16),
            ],
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: hintText,
              padding: const EdgeInsets.all(12),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Mostra un dialogo completamente personalizzabile.
  static Future<T?> showCustomDialog<T>(
      BuildContext context, {
        required Widget content,
        Widget? title,
        List<Widget>? actions,
        bool barrierDismissible = true,
      }) {
    return _showCenteredDialog<T?>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: title != null
            ? DefaultTextStyle(
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
          child: title,
        )
            : null,
        content: content,
        actions: actions ?? [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
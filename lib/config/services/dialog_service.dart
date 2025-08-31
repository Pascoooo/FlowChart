import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DialogService {
  /// Un metodo helper privato per mostrare tutti i dialoghi.
  /// Gestisce il posizionamento e le transizioni per garantire che i dialoghi
  /// siano sempre centrati, anche sul web.
  static Future<T?> _showCenteredDialog<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: child,
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
      child: CupertinoAlertDialog(
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
      child: CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              onConfirm?.call();
              Navigator.pop(context, true);
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
      child: CupertinoAlertDialog(
        title: icon != null
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isFontAwesome
                ? FaIcon(icon, color: Theme.of(context).colorScheme.primary)
                : Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        )
            : Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        content: content,
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
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
    final TextEditingController controller = TextEditingController(text: initialValue);

    return _showCenteredDialog<String?>(
      context: context,
      child: CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, null),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
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
      child: CupertinoAlertDialog(
        title: title != null
            ? DefaultTextStyle(
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
          child: title,
        )
            : null,
        content: content,
        actions: actions ??
            [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
      ),
    );
  }
}
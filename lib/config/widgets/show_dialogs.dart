import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/cupertino.dart';

class DialogService {
  static Future<T?> showCupertinoDialog<T>(
      BuildContext context, {
        required String title,
        required String message,
        String cancelText = 'Annulla',
        String? confirmText,
        VoidCallback? onConfirm,
        VoidCallback? onCancel,
        List<CupertinoDialogAction>? additionalActions,
      }) {
    return showDialog<T>(
      context: context,
      builder: (BuildContext context) {
        final actions = <CupertinoDialogAction>[];

        // Pulsante Annulla
        actions.add(
          CupertinoDialogAction(
            onPressed: () {
              onCancel?.call();
              Navigator.pop(context);
            },
            isDestructiveAction: false,
            child: Text(cancelText),
          ),
        );

        // Pulsante Conferma
        if (confirmText != null) {
          actions.add(
            CupertinoDialogAction(
              onPressed: () {
                onConfirm?.call();
                Navigator.pop(context, true);
              },
              isDefaultAction: true,
              child: Text(confirmText),
            ),
          );
        }

        // Aggiungi eventuali azioni aggiuntive
        if (additionalActions != null) {
          actions.addAll(additionalActions);
        }

        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: actions,
        );
      },
    );
  }
}
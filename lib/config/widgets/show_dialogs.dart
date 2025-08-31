import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Tipo di dialogo disponibile
enum DialogType {
  loading,
  confirmation,
  info,
  input,
  styledInput,
  custom,
}

class DialogService {
  /// Metodo unificato per mostrare dialoghi
  static Future<T?> showDialog<T>({
    required BuildContext context,
    required DialogType type,
    String? title,
    String? message,
    Widget? content,
    String? cancelText,
    String? confirmText,
    String? hintText,
    String? initialValue,
    String? subtitle,
    bool barrierDismissible = true,
    IconData? icon,
    bool isFontAwesome = false,
    bool useFilledButton = false,
    Function(String)? onConfirmInput,
    VoidCallback? onConfirm,
    List<Widget>? actions,
  }) {
    switch (type) {
      case DialogType.loading:
        return showCupertinoModalPopup<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoAlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(height: 16),
                Text(message ?? 'Caricamento in corso...'),
              ],
            ),
          ),
        );

      case DialogType.confirmation:
        return showCupertinoModalPopup<bool>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoAlertDialog(
            title: Text(title ?? ''),
            content: Text(message ?? ''),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: false,
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelText ?? 'Annulla'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  onConfirm?.call();
                  Navigator.pop(context, true);
                },
                child: Text(confirmText ?? 'Conferma'),
              ),
            ],
          ),
        ) as Future<T?>;

      case DialogType.info:
        return showCupertinoModalPopup<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoAlertDialog(
            title: title != null
                ? (icon != null
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isFontAwesome
                    ? FaIcon(icon)
                    : Icon(icon),
                const SizedBox(width: 8),
                Text(title),
              ],
            )
                : Text(title))
                : null,
            content: content,
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: Text(confirmText ?? 'OK'),
              ),
            ],
          ),
        );

      case DialogType.input:
        final TextEditingController controller = TextEditingController(text: initialValue);

        return showCupertinoModalPopup<String>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoAlertDialog(
            title: Text(title ?? 'Input'),
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
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      onConfirmInput?.call(value.trim());
                      Navigator.of(context).pop(value.trim());
                    }
                  },
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: false,
                onPressed: () => Navigator.pop(context),
                child: Text(cancelText ?? 'Annulla'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    onConfirmInput?.call(controller.text.trim());
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
                child: Text(confirmText ?? 'Conferma'),
              ),
            ],
          ),
        ) as Future<T?>;

      case DialogType.styledInput:
        final theme = Theme.of(context);
        final TextEditingController controller = TextEditingController(text: initialValue);

        return showCupertinoModalPopup<String>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoPopupSurface(
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.2),
                          theme.colorScheme.primary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isFontAwesome
                        ? FaIcon(
                      icon ?? FontAwesomeIcons.file,
                      size: 32,
                      color: theme.colorScheme.primary,
                    )
                        : Icon(
                      icon ?? Icons.edit,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CupertinoTextField(
                    controller: controller,
                    autofocus: true,
                    placeholder: hintText,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        onConfirmInput?.call(value.trim());
                        Navigator.of(context).pop(value.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(cancelText ?? 'Annulla'),
                        ),
                      ),
                      Expanded(
                        child: CupertinoButton.filled(
                          onPressed: () {
                            if (controller.text.trim().isNotEmpty) {
                              onConfirmInput?.call(controller.text.trim());
                              Navigator.of(context).pop(controller.text.trim());
                            }
                          },
                          child: Text(confirmText ?? 'Conferma'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) as Future<T?>;

      case DialogType.custom:
        return showCupertinoModalPopup<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => CupertinoAlertDialog(
            title: title != null ? Text(title) : null,
            content: content,
            actions: actions ?? [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: Text(confirmText ?? 'OK'),
              ),
            ],
          ),
        );
    }
  }

  /// Mostra un dialog con indicatore di caricamento
  static Future<void> showLoadingDialog(
      BuildContext context, {
        required String message,
        bool barrierDismissible = false,
      }) {
    return showDialog(
      context: context,
      type: DialogType.loading,
      message: message,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Mostra un dialog di conferma con due opzioni
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String content,
        String cancelText = 'Annulla',
        String confirmText = 'Conferma',
        VoidCallback? onConfirm,
        bool useFilledButton = false,
      }) {
    return showDialog<bool>(
      context: context,
      type: DialogType.confirmation,
      title: title,
      message: content,
      cancelText: cancelText,
      confirmText: confirmText,
      onConfirm: onConfirm,
    );
  }

  /// Mostra un dialog informativo con contenuto personalizzabile
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        required Widget content,
        IconData? icon,
        String okText = 'OK',
      }) {
    return showDialog(
      context: context,
      type: DialogType.info,
      title: title,
      content: content,
      icon: icon,
      confirmText: okText,
    );
  }

  /// Mostra un dialog di input con stile avanzato (per progetti/file)
  static Future<String?> showStyledInputDialog(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String hintText,
        required IconData icon,
        bool isFontAwesome = true,
        required String confirmText,
        String cancelText = 'Annulla',
        String? initialValue,
        required Function(String) onConfirm,
      }) {
    return showDialog<String>(
      context: context,
      type: DialogType.styledInput,
      title: title,
      subtitle: subtitle,
      hintText: hintText,
      icon: icon,
      isFontAwesome: isFontAwesome,
      confirmText: confirmText,
      cancelText: cancelText,
      initialValue: initialValue,
      onConfirmInput: onConfirm,
    );
  }

  /// Mostra un dialog completamente personalizzabile
  static Future<T?> showCustomDialog<T>(
      BuildContext context, {
        required Widget content,
        List<Widget>? actions,
        Widget? title,
        bool barrierDismissible = true,
      }) {
    return showDialog<T>(
      context: context,
      type: DialogType.custom,
      content: content,
      actions: actions,
      title: title as String?,
      barrierDismissible: barrierDismissible,
    );
  }
}

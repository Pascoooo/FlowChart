import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- DESCRIZIONE DELLA MODIFICA: Aggiunto un enum per rendere il dialogo informativo più versatile e type-safe. ---
enum DialogType { info, success, warning, error }

// --- REFACTOR: La classe è stata rinominata da ServiceDialog a GenericDialogs per maggiore chiarezza semantica. ---
class GenericDialogs {
  // --- UI/UX: Riprogettato per un layout più pulito e visivamente più gradevole, usando un Dialog personalizzato. ---
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        required String message,
        DialogType type = DialogType.info,
        String closeText = 'Ho capito',
      }) {
    final theme = Theme.of(context);

    // --- UX: Icona e colore vengono scelti dinamicamente in base al tipo di dialogo per un feedback visivo immediato. ---
    final Map<DialogType, (IconData, Color)> typeDetails = {
      DialogType.info: (FontAwesomeIcons.circleInfo, theme.colorScheme.primary),
      DialogType.success:
      (FontAwesomeIcons.solidCircleCheck, Colors.green.shade600),
      DialogType.warning:
      (FontAwesomeIcons.triangleExclamation, Colors.orange.shade700),
      DialogType.error: (FontAwesomeIcons.circleExclamation, theme.colorScheme.error),
    };

    final (icon, iconColor) = typeDetails[type]!;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(0.1),
                ),
                child: FaIcon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(closeText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REFACTOR: Mantenuto CupertinoAlertDialog ma con stile derivato dal tema e opzioni migliorate. ---
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        // --- UX: Aggiunto parametro 'isDestructive' per controllare lo stile dell'azione di conferma. ---
        bool isDestructive = false,
      }) {
    final theme = Theme.of(context);

    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              cancelText,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmText,
              style: TextStyle(
                // --- THEME: Il colore ora dipende dal tema e dal parametro 'isDestructive'. ---
                color: isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI/UX: Dialogo di input completamente ridisegnato per un'estetica più moderna e pulita. ---
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
      barrierDismissible: false, // L'utente deve fare una scelta esplicita.
      builder: (context) {
        // --- REFACTOR: La logica di validazione è stata mantenuta ma integrata nel nuovo design. ---
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

            // Esegui la validazione iniziale
            validate(controller.text);

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // --- UI/UX: TextField con uno stile più pulito e integrato. ---
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: hintText,
                        errorText: errorText,
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withOpacity(0.5)),
                        ),
                      ),
                      onChanged: (value) => setState(() => validate(value)),
                    ),
                    const SizedBox(height: 24),
                    // --- REFACTOR: Sostituzione di Divider/VerticalDivider con un layout basato su Row e padding. ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: Text(
                            cancelText,
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // --- UX: Il pulsante di conferma è più prominente per indicare l'azione primaria. ---
                        CupertinoButton.filled(
                          onPressed: isButtonEnabled
                              ? () =>
                              Navigator.of(context).pop(controller.text.trim())
                              : null,
                          child: Text(confirmText),
                        ),
                      ],
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
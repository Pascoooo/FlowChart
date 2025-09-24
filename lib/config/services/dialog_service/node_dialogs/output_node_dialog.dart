import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- REFACTOR: La funzione ora usa showDialog per permettere un layout personalizzato e non vincolato. ---
Future<Map<String, dynamic>?> showOutputNodeDialog(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const _OutputNodeDialog(),
  );
}

class _OutputNodeDialog extends StatefulWidget {
  const _OutputNodeDialog();

  @override
  State<_OutputNodeDialog> createState() => _OutputNodeDialogState();
}

class _OutputNodeDialogState extends State<_OutputNodeDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _messageController = TextEditingController();
    // Aggiungi un listener per aggiornare lo stato in tempo reale
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    // La validazione qui è una sicurezza aggiuntiva, ma lo stato del pulsante è già gestito.
    if (_messageController.text.trim().isNotEmpty) {
      final result = {
        'text': _labelController.text.trim().isEmpty
            ? 'Output' // Default se l'etichetta è vuota
            : _labelController.text.trim(),
        'template': _messageController.text.trim(),
      };
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // --- DESCRIZIONE DELLA MODIFICA: La validità è calcolata direttamente qui per la massima reattività. ---
    final isValid = _messageController.text.trim().isNotEmpty;

    // --- REFACTOR: Sostituzione di CupertinoAlertDialog con un Dialog personalizzato per un controllo totale su UI/UX. ---
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- UI/UX: Titolo e icona sono ora più prominenti e integrati nel layout. ---
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.terminal,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text('Configura Nodo Output',
                    style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Definisci il messaggio che verrà mostrato al termine del flusso.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // --- UI/UX: Aggiunta di etichette esplicite sopra i campi per maggiore chiarezza. ---
            Text('Etichetta Nodo (opzionale)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _labelController,
              placeholder: 'Es. Risultato Finale',
              style: theme.textTheme.bodyMedium,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Messaggio di Output *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _messageController,
              placeholder: 'Es. Il calcolo è: {{risultato}}',
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
            ),
            const SizedBox(height: 16),
            // --- UI/UX: Il testo di aiuto è stato ridisegnato per essere più visibile e leggibile. ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.lightbulb,
                    size: 14,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Usa {{variabile}} per inserire valori dinamici',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // --- UI/UX: Le azioni ora usano CupertinoButton per uno stile coerente e una chiara gerarchia. ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    'Annulla',
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                  onPressed: isValid ? _onConfirm : null,
                  child: const Text('Conferma'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
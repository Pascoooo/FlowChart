import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Import necessario per poter usare il tipo VariableDeclaration
import 'package:flowchart_repository/flowchart_repository.dart';

// --- MODIFICA: La funzione ora accetta la lista di variabili disponibili ---
Future<Map<String, dynamic>?> showOutputNodeDialog(
    BuildContext context, {
      required List<VariableDeclaration> availableVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    // Passiamo le variabili al widget del dialogo
    builder: (_) => _OutputNodeDialog(variables: availableVariables),
  );
}

class _OutputNodeDialog extends StatefulWidget {
  // --- MODIFICA: Il dialogo ora riceve la lista di variabili ---
  final List<VariableDeclaration> variables;
  const _OutputNodeDialog({required this.variables});

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

  /// --- NUOVA FUNZIONE: Inserisce il segnaposto di una variabile nel testo ---
  void _insertVariable(String variableName) {
    final textToInsert = '{$variableName}';
    final currentText = _messageController.text;
    final selection = _messageController.selection;
    final newText = currentText.replaceRange(selection.start, selection.end, textToInsert);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + textToInsert.length),
    );
  }

  void _onConfirm() {
    if (_messageController.text.trim().isNotEmpty) {
      // --- MODIFICA: Estrae i nomi delle variabili usate nel template ---
      final RegExp regex = RegExp(r'\{(\w+)\}');
      final matches = regex.allMatches(_messageController.text);
      final usedVariables = matches.map((m) => m.group(1)!).toSet().toList();

      final result = {
        'text': _labelController.text.trim().isEmpty
            ? 'Output'
            : _labelController.text.trim(),
        'template': _messageController.text.trim(),
        'variables': usedVariables, // Aggiungiamo la lista di variabili usate
      };
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _messageController.text.trim().isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              'Definisci il messaggio che verrà mostrato e le variabili da usare.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            Text('Etichetta Nodo (opzionale)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _labelController,
              placeholder: 'Es. Risultato Finale',
              // ... (resto del textfield invariato)
            ),
            const SizedBox(height: 16),
            Text('Messaggio di Output *', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _messageController,
              placeholder: 'Es. Il calcolo è: {{risultato}}',
              maxLines: 3,
              // ... (resto del textfield invariato)
            ),

            // --- NUOVO WIDGET: Lista delle variabili come chip ---
            if (widget.variables.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Variabili disponibili', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: widget.variables.map((variable) {
                  return ActionChip(
                    label: Text(variable.name),
                    avatar: FaIcon(FontAwesomeIcons.code, size: 12),
                    onPressed: () => _insertVariable(variable.name),
                    tooltip: 'Inserisci {{${variable.name}}}',
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
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
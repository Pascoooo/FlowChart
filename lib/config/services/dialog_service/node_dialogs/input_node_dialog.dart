import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

Future<Map<String, dynamic>?> showInputNodeDialog(
    BuildContext context, {
      required List<VariableDeclaration> availableInputVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InputNodeDialog(
      availableInputVariables: availableInputVariables,
    ),
  );
}

class _InputNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> availableInputVariables;

  const _InputNodeDialog({
    required this.availableInputVariables,
  });

  @override
  State<_InputNodeDialog> createState() => _InputNodeDialogState();
}

class _InputNodeDialogState extends State<_InputNodeDialog> {
  // Mappa per tenere traccia delle variabili selezionate
  final Map<String, bool> _selectedVariables = {};

  @override
  void initState() {
    super.initState();
    // Inizializza la mappa con tutte le variabili di input disponibili come non selezionate
    for (var variable in widget.availableInputVariables) {
      _selectedVariables[variable.name] = false;
    }
  }

// Dentro la classe _InputNodeDialogState

  void _confirm() {
    // Filtra per ottenere solo i NOMI delle variabili selezionate
    final selectedNames = widget.availableInputVariables
        .where((v) => _selectedVariables[v.name] == true)
        .map((v) => v.name)
        .toList();

    if (selectedNames.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final names = selectedNames.join(', ');
    final nodeText = 'Prendi in input $names';

    // FIX: Restituisci 'targetVariables' come lista di stringhe (nomi), NON 'declarations'
    Navigator.of(context).pop({
      'text': nodeText,
      'targetVariables': selectedNames,  // Lista di nomi (String)
    });
  }
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      title: const Text('Seleziona Variabili di Input'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scegli quali variabili, tra quelle definite come "Input", vuoi leggere in questo passaggio del programma.',
            style: theme.typography.body,
          ),
          const SizedBox(height: 16),
          Text('Variabili da prendere in input', style: theme.typography.subtitle),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.resources.dividerStrokeColorDefault),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: widget.availableInputVariables.length,
                itemBuilder: (context, index) {
                  final variable = widget.availableInputVariables[index];
                  return ListTile(
                    title: Text(variable.name, style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Text(variable.dataType),
                    trailing: Checkbox(
                      checked: _selectedVariables[variable.name],
                      onChanged: (checked) {
                        setState(() {
                          _selectedVariables[variable.name] = checked ?? false;
                        });
                      },
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedVariables[variable.name] = !(_selectedVariables[variable.name] ?? false);
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
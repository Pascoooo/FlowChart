// file: lib/config/services/dialog_service/node_dialogs/input_node_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Mostra il dialog di configurazione per un nodo Input.
///
/// Ritorna un [Map] con la configurazione del nodo o null se annullato.
/// Il dialog è sempre mostrato, anche se [availableInputVariables] è vuota.
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

  const _InputNodeDialog({required this.availableInputVariables});

  @override
  State<_InputNodeDialog> createState() => _InputNodeDialogState();
}

class _InputNodeDialogState extends State<_InputNodeDialog> {
  final TextEditingController _labelController = TextEditingController();
  final Map<String, bool> _selectedVariables = {};
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    // Inizializza la mappa delle variabili con 'false' (non selezionato)
    for (final variable in widget.availableInputVariables) {
      _selectedVariables[variable.name] = false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// Valida che almeno una variabile sia stata selezionata.
  bool _validateForm() {
    return _selectedVariables.values.any((isSelected) => isSelected);
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    // Estrae i nomi delle variabili selezionate
    final selectedNames = _selectedVariables.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final names = selectedNames.join(', ');

    // Ritorna la configurazione
    Navigator.of(context).pop({
      'text': _labelController.text.trim().isEmpty
          ? 'Prendi in input: $names'
          : _labelController.text.trim(),
      'targetVariables': selectedNames,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasVariables = widget.availableInputVariables.isNotEmpty;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 20),
            if (!hasVariables) _buildNoVariablesInfo(theme),
            if (hasVariables) ...[
              InfoLabel(
                label: 'Etichetta Nodo (opzionale)',
                child: TextBox(
                  controller: _labelController,
                  placeholder: 'Es. Inserimento Dati Utente',
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Variabili da Leggere *',
                    style: theme.typography.subtitle),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _buildVariableList(theme),
              ),
              if (_attemptedSubmit && !_validateForm())
                _buildErrorMessage(theme),
            ],
            const SizedBox(height: 24),
            _buildDialogActions(hasVariables),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.arrowRightToBracket,
            color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo Input', style: theme.typography.title),
              Text(
                'Seleziona quali variabili di input leggere.',
                style: theme.typography.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoVariablesInfo(FluentThemeData theme) {
    return Expanded(
      child: Center(
        child: InfoBar(
          title: const Text('Nessuna variabile di input disponibile'),
          content: const Text(
            'Per configurare questo nodo, devi prima creare delle variabili di input nel progetto.',
          ),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ),
    );
  }

  Widget _buildVariableList(FluentThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey[20]
            : theme.cardColor.withOpacity(0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: widget.availableInputVariables.length,
        itemBuilder: (_, i) {
          final variable = widget.availableInputVariables[i];
          final varName = variable.name;
          final bool isSelected = _selectedVariables[varName] ?? false;

          return ListTile(
            leading: Checkbox(
              checked: isSelected,
              onChanged: (bool? checked) {
                setState(() {
                  _selectedVariables[varName] = checked ?? false;
                });
              },
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    variable.dataType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  variable.name,
                  style: const TextStyle(
                    fontFamily: 'Consolas, Monaco, monospace',
                  ),
                ),
              ],
            ),
            onPressed: () {
              setState(() {
                // Toggle the selection when the tile is tapped
                _selectedVariables[varName] = !isSelected;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorMessage(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        'È necessario selezionare almeno una variabile.',
        style: theme.typography.caption
            ?.copyWith(color: Colors.red.defaultBrushFor(theme.brightness)),
      ),
    );
  }

  Widget _buildDialogActions(bool hasVariables) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          style: ButtonStyle(
            padding: ButtonState.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
          child: const Text('Annulla'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: hasVariables ? _confirm : null,
          style: ButtonStyle(
            padding: ButtonState.all(
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

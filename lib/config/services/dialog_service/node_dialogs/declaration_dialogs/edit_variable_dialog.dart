// lib/presentation/widgets/dialogs/node_dialogs/edit_variable_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

/// Un dialogo per modificare una variabile esistente.
/// Permette di cambiare nome e tipo (se non usata in condizioni), ma non lo scope.
class EditVariableDialog extends StatefulWidget {
  final VariableDeclaration variableToEdit;
  final Set<String> existingVariableNames;
  final bool canEditType;

  const EditVariableDialog({
    super.key,
    required this.variableToEdit,
    required this.existingVariableNames,
    this.canEditType = true,
  });

  @override
  State<EditVariableDialog> createState() => _EditVariableDialogState();
}

class _EditVariableDialogState extends State<EditVariableDialog> {
  final _nameController = TextEditingController();
  late String _selectedType;
  String? _nameError;
  bool _attemptedSubmit = false;

  static const _cTypes = <String>['int', 'float', 'double', 'bool', 'string'];

  @override
  void initState() {
    super.initState();
    // Pre-compila i campi con i valori della variabile esistente
    _nameController.text = widget.variableToEdit.name;
    _selectedType = widget.variableToEdit.dataType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Valida il form e aggiorna lo stato dell'errore.
  /// Restituisce `true` se il form è valido.
  bool _validateForm() {
    final name = _nameController.text.trim();
    final startsWithNumber = RegExp(r'^[0-9]');
    final isOnlyNumbers = RegExp(r'^[0-9]+$');
    final isValidIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

    setState(() {
      if (name.isEmpty) {
        _nameError = 'Il nome è obbligatorio.';
      } else if (startsWithNumber.hasMatch(name)) {
        _nameError = 'Il nome non può iniziare con un numero.';
      } else if (isOnlyNumbers.hasMatch(name)) {
        _nameError = 'Il nome non può essere composto solo da numeri.';
      } else if (!isValidIdentifier.hasMatch(name)) {
        _nameError = 'Formato non valido (es: my_var, var1).';
      } else if (name != widget.variableToEdit.name &&
          widget.existingVariableNames.contains(name)) {
        // Controlla la duplicazione solo se il nome è diverso da quello originale
        _nameError = 'Questo nome è già utilizzato.';
      } else {
        _nameError = null;
      }
    });

    return _nameError == null;
  }

  /// Gestisce il click sul pulsante di conferma.
  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    final updatedVariable = VariableDeclaration(
      name: _nameController.text.trim(),
      dataType: _selectedType,
      scope: widget.variableToEdit.scope, // Lo scope non è modificabile
    );

    // Restituisce un Map con la variabile aggiornata e il vecchio nome
    Navigator.of(context).pop({
      'variable': updatedVariable,
      'oldName': widget.variableToEdit.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: Text('Modifica Variabile "${widget.variableToEdit.name}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Nome Variabile *',
            child: TextBox(
              controller: _nameController,
              onChanged: (_) {
                if (_attemptedSubmit) _validateForm();
              },
            ),
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _nameError!,
                style: TextStyle(color: Colors.red.lightest),
              ),
            ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Tipo di Dato *',
            child: Tooltip(
              message: widget.canEditType
                ? ''
                : 'Il tipo non può essere modificato perché questa variabile è utilizzata in una condizione',
              child: ComboBox<String>(
                isExpanded: true,
                value: _selectedType,
                items: _cTypes
                    .map((t) => ComboBoxItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: widget.canEditType
                  ? (val) => setState(() {
                      if (val != null) _selectedType = val;
                    })
                  : null,
              ),
            ),
          ),
          if (!widget.canEditType)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(FluentIcons.info, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Il tipo non può essere modificato perché questa variabile è usata in una condizione.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          InfoLabel(
            label: 'Categoria (non modificabile)',
            child: TextBox(
              enabled: false,
              controller: TextEditingController(
                text: widget.variableToEdit.scope.name.toUpperCase(),
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
          child: const Text('Salva Modifiche'),
        ),
      ],
    );
  }
}
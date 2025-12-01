// lib/presentation/widgets/dialogs/node_dialogs/add_variable_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

/// Un dialogo per creare una nuova variabile, specificando nome e tipo.
/// Lo scope (input, output, local) viene passato come parametro per
/// determinare il titolo e il comportamento.
class AddVariableDialog extends StatefulWidget {
  final VariableScope scope;
  final Set<String> existingVariableNames;

  const AddVariableDialog({
    super.key,
    required this.scope,
    required this.existingVariableNames,
  });

  @override
  State<AddVariableDialog> createState() => _AddVariableDialogState();
}

class _AddVariableDialogState extends State<AddVariableDialog> {
  final _nameController = TextEditingController();
  String _selectedType = 'int'; // Tipo di dato predefinito
  String? _nameError;
  bool _attemptedSubmit = false;

  // Tipi di dato supportati, in linea con lo standard C
  static const _cTypes = <String>['int', 'float', 'double', 'bool', 'string'];

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
      } else if (widget.existingVariableNames.contains(name)) {
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
    if (!_validateForm()) return; // Se la validazione fallisce, non procedere

    final newVariable = VariableDeclaration(
      name: _nameController.text.trim(),
      dataType: _selectedType,
      scope: widget.scope,
    );

    // Ritorna la nuova variabile alla chiamata precedente
    Navigator.of(context).pop(newVariable);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: Text('Aggiungi Variabile di ${widget.scope.name.toUpperCase()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Nome Variabile *',
            child: TextBox(
              controller: _nameController,
              placeholder: 'es. user_age',
              onChanged: (_) {
                // R-evaluta il form a ogni modifica se l'utente ha già provato a inviare
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
            child: ComboBox<String>(
              isExpanded: true,
              value: _selectedType,
              items: _cTypes
                  .map((t) => ComboBoxItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() {
                if (val != null) _selectedType = val;
              }),
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
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}
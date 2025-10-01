import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<VariableDeclaration?> showVariableDialog(
    BuildContext context, {
      required VariableScope defaultScope,
      required List<VariableDeclaration> existingDeclarations,
    }) {
  return showDialog<VariableDeclaration>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _VariableDialog(
      defaultScope: defaultScope,
      existingDeclarations: existingDeclarations,
    ),
  );
}

class _VariableDialog extends StatefulWidget {
  final VariableScope defaultScope;
  final List<VariableDeclaration> existingDeclarations;

  const _VariableDialog({
    required this.defaultScope,
    required this.existingDeclarations,
  });

  @override
  State<_VariableDialog> createState() => _VariableDialogState();
}

class _VariableDialogState extends State<_VariableDialog> {
  late _VarRowData _varData;
  bool _attemptedSubmit = false;

  static const _cTypes = <String>['int', 'float', 'double', 'bool', 'char', 'string'];

  @override
  void initState() {
    super.initState();
    _varData = _VarRowData(
      type: 'int',
      scope: widget.defaultScope,
    );
  }

  @override
  void dispose() {
    _varData.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isFormValid = true;
    final v = _varData;
    final name = v.name.text.trim();
    final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

    if (name.isEmpty) {
      v.nameError = 'Obbligatorio';
      isFormValid = false;
    } else if (!idRe.hasMatch(name)) {
      v.nameError = 'Formato non valido';
      isFormValid = false;
    } else if (widget.existingDeclarations.any((d) => d.name == name)) {
      v.nameError = 'Nome già in uso';
      isFormValid = false;
    } else {
      v.nameError = null;
    }

    setState(() {});
    return isFormValid;
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    final v = _varData;
    final newVariable = VariableDeclaration(
      name: v.name.text.trim(),
      dataType: v.type,
      scope: v.scope,
    );

    Navigator.of(context).pop(newVariable);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700), // Rimpicciolito
      title: Text('Aggiungi Variabile (${widget.defaultScope.name})'),
      content: _buildVarRow(FluentTheme.of(context)),
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

  Widget _buildVarRow(FluentThemeData theme) {
    final v = _varData;
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InfoLabel(
                  label: 'Nome Variabile *',
                  child: TextBox(controller: v.name, onChanged: (_) {
                    if (_attemptedSubmit) _validateForm();
                  }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Tipo *',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: v.type,
                    items: _cTypes.map((t) => ComboBoxItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() {
                      if (val != null) v.type = val;
                    }),
                  ),
                ),
              ),
            ],
          ),
          if (_attemptedSubmit && v.nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _ErrorMessage(v.nameError ?? '')),
                  const SizedBox(width: 16),
                  const Spacer(flex: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Helper widgets
class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage(this.message);

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Icon(FluentIcons.warning, size: 12, color: Colors.red.defaultBrushFor(theme.brightness)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            message,
            style: theme.typography.caption?.copyWith(color: Colors.red.defaultBrushFor(theme.brightness)),
          ),
        ),
      ],
    );
  }
}

class _VarRowData {
  final TextEditingController name = TextEditingController();
  VariableScope scope;
  String type;
  String? nameError;

  _VarRowData({required this.type, required this.scope});

  void dispose() {
    name.dispose();
  }
}
import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

Future<Map<String, dynamic>?> showInputNodeDialog(
    BuildContext context, {
      required Set<String> existingVariableNames,
      required List<VariableDeclaration> existingDeclarations,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InputNodeDialog(
      existingDeclarations: existingDeclarations,
    ),
  );
}

class _InputNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> existingDeclarations;

  const _InputNodeDialog({
    required this.existingDeclarations,
  });

  @override
  State<_InputNodeDialog> createState() => _InputNodeDialogState();
}

class _InputNodeDialogState extends State<_InputNodeDialog> {
  final List<_VarRowData> _vars = [];
  bool _attemptedSubmit = false;

  static const _cTypes = <String>['int', 'float', 'double', 'bool', 'char', 'string'];

  @override
  void initState() {
    super.initState();
    _addVar();
  }

  @override
  void dispose() {
    for (final v in _vars) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVar() => setState(() => _vars.add(_VarRowData(type: 'int', hasInit: false)));

  void _removeVar(int i) {
    setState(() {
      _vars[i].dispose();
      _vars.removeAt(i);
    });
    if (_attemptedSubmit) _validateForm();
  }

  bool _validateValue(String type, String value) {
    if (value.isEmpty) return false;
    switch (type) {
      case 'int':
        return int.tryParse(value) != null;
      case 'float':
      case 'double':
        return double.tryParse(value) != null;
      case 'bool':
        return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char':
        return value.length == 1;
      case 'string':
        return true;
      default:
        return false;
    }
  }

  bool _validateForm() {
    final names = <String, List<int>>{};
    bool isFormValid = true;

    for (var i = 0; i < _vars.length; i++) {
      final v = _vars[i];
      final name = v.name.text.trim();
      final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

      if (name.isEmpty) {
        v.nameError = 'Obbligatorio';
      } else if (!idRe.hasMatch(name)) {
        v.nameError = 'Formato non valido';
      } else if (widget.existingDeclarations.any((d) => d.name == name)) {
        v.nameError = 'Nome già in uso';
      } else {
        v.nameError = null;
        names.putIfAbsent(name, () => []).add(i);
      }

      if (v.hasInit) {
        final val = v.init.text.trim();
        if (val.isEmpty) {
          v.initError = 'Obbligatorio';
        } else if (!_validateValue(v.type, val)) {
          v.initError = 'Valore non valido';
        } else {
          v.initError = null;
        }
      } else {
        v.initError = null;
      }
      if (v.nameError != null || v.initError != null) isFormValid = false;
    }

    names.forEach((_, indices) {
      if (indices.length > 1) {
        isFormValid = false;
        for (var index in indices) {
          _vars[index].nameError = 'Nome duplicato';
        }
      }
    });

    setState(() {});
    return isFormValid;
  }

  dynamic _parseValue(String type, String value) {
    if (value.isEmpty) return null;
    switch (type) {
      case 'int':
        return int.tryParse(value) ?? 0;
      case 'float':
      case 'double':
        return double.tryParse(value) ?? 0.0;
      case 'bool':
        return ['true', '1'].contains(value.toLowerCase());
      case 'char':
        return value.length == 1 ? value : null;
      default:
        return value;
    }
  }

  String _generateAutoLabel() {
    final declaredNames = _vars
        .map((v) => v.name.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (declaredNames.isEmpty) return 'Nodo Input';
    return 'Prendi in input ${declaredNames.join(', ')}';
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _generateAutoLabel(),
      'declarations': _vars.where((v) => v.name.text.trim().isNotEmpty).map((v) {
        final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
        return {
          'name': v.name.text.trim(),
          'dataType': v.type,
          'defaultValue': defaultValue
        };
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
      content: SizedBox(
        height: 680,
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 20),
            Expanded(
              child: _buildDeclarationsSection(theme),
            ),
            const SizedBox(height: 12),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclarationsSection(FluentThemeData theme) {
    return Column(
      children: [
        _buildVarHeader(theme),
        const SizedBox(height: 16),
        Expanded(
          child: _vars.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: _vars.length,
            itemBuilder: (_, i) => _buildVarRow(i, theme),
            separatorBuilder: (_, __) => const SizedBox(height: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.keyboard, color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo Input', style: theme.typography.title),
              Text('Definisci una o più nuove variabili da leggere in input.',
                  style: theme.typography.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVarHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Variabili di Input', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: _addVar,
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.plus, size: 14),
              SizedBox(width: 8),
              Text('Aggiungi Variabile'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FontAwesomeIcons.circleInfo, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text('Nessuna variabile definita', style: theme.typography.bodyLarge),
          const SizedBox(height: 4),
          Text('Aggiungi la prima variabile per iniziare.', style: theme.typography.caption),
        ],
      ),
    );
  }

  Widget _buildVarRow(int index, FluentThemeData theme) {
    final v = _vars[index];
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey[20]
            : theme.cardColor.withOpacity(0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
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
                      if (val != null) {
                        v.type = val;
                        v.init.clear();
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: AnimatedOpacity(
                  opacity: v.hasInit ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: InfoLabel(
                    label: 'Valore Iniziale',
                    child: TextBox(
                      controller: v.init,
                      enabled: v.hasInit,
                      onChanged: (_) {
                        if (_attemptedSubmit) _validateForm();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  const Text('Inizializza?', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Checkbox(
                    checked: v.hasInit,
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        v.hasInit = val;
                        if (!val) v.init.clear();
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeVar(index),
                style: ButtonStyle(
                  foregroundColor: ButtonState.resolveWith((states) {
                    final color = Colors.red.defaultBrushFor(theme.brightness);
                    return states.isHovering ? Colors.white : color;
                  }),
                  backgroundColor: ButtonState.resolveWith(
                          (states) => states.isHovering ? Colors.red : Colors.transparent),
                ),
                icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
              ),
            ],
          ),
          if (_attemptedSubmit && (v.nameError != null || v.initError != null))
            _buildErrorMessages(v),
        ],
      ),
    );
  }

  Widget _buildErrorMessages(_VarRowData v) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: _ErrorMessage(v.nameError ?? '')),
          const SizedBox(width: 16),
          const Spacer(flex: 2),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: _ErrorMessage(v.initError ?? '')),
          const SizedBox(width: 16),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildDialogActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

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
  String type;
  bool hasInit;
  final TextEditingController init = TextEditingController();

  String? nameError;
  String? initError;

  _VarRowData({required this.type, required this.hasInit});

  void dispose() {
    name.dispose();
    init.dispose();
  }
}
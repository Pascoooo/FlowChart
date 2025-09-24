import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<Map<String, dynamic>?> showDecisionNodeDialog(
    BuildContext context, {
      required List<Map<String, String>> variables, // each: {name, type}
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _DecisionNodeDialog(variables: variables),
  );
}

// --- ENUM PER MODALITÀ E STATO ---
enum _ConditionMode { simple, advanced }
enum _RightHandMode { literal, variable }

class _DecisionNodeDialog extends StatefulWidget {
  final List<Map<String, String>> variables;
  const _DecisionNodeDialog({required this.variables});

  @override
  State<_DecisionNodeDialog> createState() => _DecisionNodeDialogState();
}

class _DecisionNodeDialogState extends State<_DecisionNodeDialog> {
  _ConditionMode _mode = _ConditionMode.simple;
  final TextEditingController _labelController = TextEditingController();
  bool _attemptedSubmit = false;

  // Stato per la modalità Semplice
  _ComparisonRow _simpleRow = _ComparisonRow();

  // Stato per la modalità Avanzata
  final List<_ComparisonRow> _advancedRows = [];
  final List<String> _connectors = []; // AND / OR

  static const _opsNumeric = ['==', '!=', '<', '<=', '>', '>='];
  static const _opsGeneric = ['==', '!='];

  @override
  void initState() {
    super.initState();
    // Inizializza la riga semplice con la prima variabile, se disponibile
    if (widget.variables.isNotEmpty) {
      _simpleRow.leftVariable = widget.variables.first['name'];
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _simpleRow.dispose();
    for (final r in _advancedRows) {
      r.dispose();
    }
    super.dispose();
  }

  List<String> _opsForType(String? type) {
    switch (type) {
      case 'int':
      case 'float':
      case 'double':
        return _opsNumeric;
      default:
        return _opsGeneric;
    }
  }

  Map<String, String>? _varMeta(String? name) =>
      widget.variables.firstWhere((v) => v['name'] == name, orElse: () => {});

  // --- REFACTOR: Sistema di validazione unificato e granulare ---
  bool _validateForm() {
    bool isFormValid = true;

    if (_mode == _ConditionMode.simple) {
      isFormValid = _validateRow(_simpleRow);
    } else {
      if (_advancedRows.isEmpty) return false;
      for (var row in _advancedRows) {
        if (!_validateRow(row)) {
          isFormValid = false;
        }
      }
      if (!_areParenthesesBalanced()) {
        isFormValid = false;
      }
    }
    return isFormValid;
  }

  bool _validateRow(_ComparisonRow row) {
    bool isRowValid = true;
    final leftType = _varMeta(row.leftVariable)?['type'];

    // Validazione operando sinistro
    if (row.leftVariable == null) {
      row.leftError = 'Scegli una variabile';
      isRowValid = false;
    } else {
      row.leftError = null;
    }

    // Validazione operando destro
    if (row.rightMode == _RightHandMode.literal) {
      final literal = row.literalController.text.trim();
      if (literal.isEmpty) {
        row.rightError = 'Valore obbligatorio';
        isRowValid = false;
      } else if (leftType != null && !_validateLiteral(leftType, literal)) {
        row.rightError = 'Non valido per il tipo "$leftType"';
        isRowValid = false;
      } else {
        row.rightError = null;
      }
    } else {
      final rightType = _varMeta(row.rightVariable)?['type'];
      if (row.rightVariable == null) {
        row.rightError = 'Scegli una variabile';
        isRowValid = false;
      } else if (leftType != null &&
          rightType != null &&
          leftType != rightType) {
        row.rightError = 'I tipi ($leftType, $rightType) non corrispondono';
        isRowValid = false;
      } else {
        row.rightError = null;
      }
    }
    return isRowValid;
  }

  bool _validateLiteral(String type, String value) {
    if (value.isEmpty) return false;
    switch (type) {
      case 'int': return int.tryParse(value) != null;
      case 'float':
      case 'double': return double.tryParse(value) != null;
      case 'bool': return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1 || (value.length == 3 && value.startsWith("'") && value.endsWith("'"));
      case 'string': return true;
      default: return true;
    }
  }

  bool _areParenthesesBalanced() {
    int balance = 0;
    for (final row in _advancedRows) {
      for (final char in row.leftParenController.text.trim().split('')) {
        if (char == '(') balance++;
      }
      for (final char in row.rightParenController.text.trim().split('')) {
        if (char == ')') balance--;
      }
      if (balance < 0) return false; // Chiusura prima di apertura
    }
    return balance == 0;
  }

  void _switchToAdvanced() {
    setState(() {
      _mode = _ConditionMode.advanced;
      if (_advancedRows.isEmpty) {
        _advancedRows.add(_simpleRow.clone());
      }
    });
  }

  void _addRow() {
    setState(() {
      _advancedRows.add(_ComparisonRow(
          leftVariable: widget.variables.isNotEmpty
              ? widget.variables.first['name']
              : null));
      if (_advancedRows.length > 1) _connectors.add('AND');
    });
  }

  void _removeRow(int index) {
    setState(() {
      _advancedRows[index].dispose();
      _advancedRows.removeAt(index);
      if (_connectors.isNotEmpty) {
        if (index < _connectors.length) {
          _connectors.removeAt(index);
        } else {
          _connectors.removeLast();
        }
      }
      if (_attemptedSubmit) _validateForm();
    });
  }

  String _buildExpression() {
    final rowsToBuild =
    _mode == _ConditionMode.simple ? [_simpleRow] : _advancedRows;
    if (rowsToBuild.isEmpty) return '';

    List<String> parts = [];
    for (int i = 0; i < rowsToBuild.length; i++) {
      final row = rowsToBuild[i];
      final left = row.leftVariable ?? '?';
      final op = row.operator;
      String right;
      if (row.rightMode == _RightHandMode.literal) {
        final type = _varMeta(row.leftVariable)?['type'] ?? 'string';
        right = _normalizedLiteral(type, row.literalController.text);
      } else {
        right = row.rightVariable ?? '?';
      }

      final leftParen = row.leftParenController.text.trim();
      final rightParen = row.rightParenController.text.trim();

      parts.add('$leftParen$left $op $right$rightParen');

      if (_mode == _ConditionMode.advanced && i < _connectors.length) {
        parts.add(_connectors[i]);
      }
    }
    return parts.join(' ');
  }

  String _normalizedLiteral(String type, String raw) {
    var v = raw.trim();
    switch (type) {
      case 'char': return v.length == 1 ? "'$v'" : v;
      case 'string': return (v.startsWith('"') && v.endsWith('"')) ? v : '"${v.replaceAll('"', '\\"')}"';
      default: return v;
    }
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _labelController.text.trim().isEmpty ? 'Condizione' : _labelController.text.trim(),
      'condition': _buildExpression(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expressionPreview = _buildExpression();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(24.0),
        child: widget.variables.isEmpty
            ? Center(child: Text('Nessuna variabile definita.', style: TextStyle(color: theme.hintColor)))
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              FaIcon(FontAwesomeIcons.codeBranch, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text('Configura Nodo Condizione', style: theme.textTheme.headlineSmall),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: TextField(controller: _labelController, decoration: const InputDecoration(labelText: 'Etichetta Nodo (opzionale)'))),
              const SizedBox(width: 24),
              Expanded(
                child: CupertinoSlidingSegmentedControl<_ConditionMode>(
                  groupValue: _mode,
                  onValueChanged: (value) {
                    if (value == _ConditionMode.advanced) _switchToAdvanced();
                    else setState(() => _mode = value!);
                  },
                  children: const {
                    _ConditionMode.simple: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Semplice')),
                    _ConditionMode.advanced: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('Avanzato')),
                  },
                ),
              ),
            ]),
            const SizedBox(height: 24),
            // --- UI/UX: Transizione animata tra modalità semplice e avanzata ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: _mode == _ConditionMode.simple
                  ? _buildSimpleUI(theme)
                  : _buildAdvancedUI(theme),
            ),
            const SizedBox(height: 16),
            _buildPreview(theme, expressionPreview),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              CupertinoButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
              const SizedBox(width: 8),
              CupertinoButton.filled(onPressed: _confirm, child: const Text('Conferma')),
            ]),
          ],
        ),
      ),
    );
  }

  // --- UI/UX: Interfaccia per la modalità semplice, pulita e guidata. ---
  Widget _buildSimpleUI(ThemeData theme) {
    return _buildComparisonRow(_simpleRow, 0, theme, isSimpleMode: true);
  }

  // --- UI/UX: Interfaccia per la modalità avanzata con lista di condizioni. ---
  Widget _buildAdvancedUI(ThemeData theme) {
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 350),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _advancedRows.length,
                itemBuilder: (context, index) {
                  final row = _advancedRows[index];
                  return Column(
                    children: [
                      _buildComparisonRow(row, index, theme),
                      if (index < _connectors.length)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: DropdownButtonFormField<String>(
                            value: _connectors[index],
                            items: const [
                              DropdownMenuItem(value: 'AND', child: Text('AND (entrambe vere)')),
                              DropdownMenuItem(value: 'OR', child: Text('OR (almeno una vera)')),
                            ],
                            onChanged: (val) => setState(() => _connectors[index] = val!),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (_attemptedSubmit && !_areParenthesesBalanced())
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Errore: le parentesi non sono bilanciate.', style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: _addRow,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  FaIcon(FontAwesomeIcons.plus, size: 14),
                  SizedBox(width: 8),
                  Text('Aggiungi Condizione'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI/UX: Widget unificato per costruire una riga di comparazione, con UI ridisegnata. ---
  Widget _buildComparisonRow(_ComparisonRow row, int index, ThemeData theme, {bool isSimpleMode = false}) {
    final leftType = _varMeta(row.leftVariable)?['type'];
    final availableOps = _opsForType(leftType);
    if (!availableOps.contains(row.operator)) row.operator = availableOps.first;

    return Column(
      key: ValueKey(row), // Chiave per animazioni corrette
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSimpleMode)
              SizedBox(width: 50, child: TextField(controller: row.leftParenController, decoration: const InputDecoration(labelText: '('))),

            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: row.leftVariable,
                items: widget.variables.map((v) => DropdownMenuItem(value: v['name'], child: Text(v['name']!))).toList(),
                onChanged: (val) => setState(() {
                  row.leftVariable = val;
                  row.rightVariable = null;
                }),
                decoration: InputDecoration(labelText: 'Variabile', errorText: _attemptedSubmit ? row.leftError : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: row.operator,
                items: availableOps.map((op) => DropdownMenuItem(value: op, child: Center(child: Text(op)))).toList(),
                onChanged: (val) => setState(() => row.operator = val!),
                decoration: const InputDecoration(labelText: 'Operatore'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: row.rightMode == _RightHandMode.variable
                    ? DropdownButtonFormField<String>(
                  key: const ValueKey('variable'),
                  value: row.rightVariable,
                  items: widget.variables
                      .where((v) => v['name'] != row.leftVariable)
                      .map((v) => DropdownMenuItem(value: v['name'], child: Text(v['name']!)))
                      .toList(),
                  onChanged: (val) => setState(() => row.rightVariable = val),
                  decoration: InputDecoration(labelText: 'Variabile', errorText: _attemptedSubmit ? row.rightError : null),
                )
                    : TextField(
                  key: const ValueKey('literal'),
                  controller: row.literalController,
                  decoration: InputDecoration(labelText: 'Valore', errorText: _attemptedSubmit ? row.rightError : null),
                  onChanged: (_) { if (_attemptedSubmit) setState(_validateForm); },
                ),
              ),
            ),
            if (!isSimpleMode)
              SizedBox(width: 50, child: TextField(controller: row.rightParenController, decoration: const InputDecoration(labelText: ')'))),

            Column(
              children: [
                CupertinoSlidingSegmentedControl<_RightHandMode>(
                  groupValue: row.rightMode,
                  onValueChanged: (val) => setState(() => row.rightMode = val!),
                  children: const {
                    _RightHandMode.literal: FaIcon(FontAwesomeIcons.quoteLeft, size: 12),
                    _RightHandMode.variable: FaIcon(FontAwesomeIcons.at, size: 12),
                  },
                ),
                if (!isSimpleMode)
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.trashCan, color: theme.colorScheme.error, size: 16),
                    onPressed: () => _removeRow(index),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(ThemeData theme, String expr) {
    if (expr.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anteprima Espressione', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(expr, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

// --- REFACTOR: Classe dati ora include controller per le parentesi e campi specifici per gli errori. ---
class _ComparisonRow {
  String? leftVariable;
  String operator;
  _RightHandMode rightMode;
  String? rightVariable;
  TextEditingController literalController;
  TextEditingController leftParenController;
  TextEditingController rightParenController;
  String? leftError;
  String? rightError;

  _ComparisonRow({
    this.leftVariable,
    this.operator = '==',
    this.rightMode = _RightHandMode.literal,
    this.rightVariable,
  })  : literalController = TextEditingController(),
        leftParenController = TextEditingController(),
        rightParenController = TextEditingController();

  _ComparisonRow._clone(_ComparisonRow original) :
        leftVariable = original.leftVariable,
        operator = original.operator,
        rightMode = original.rightMode,
        rightVariable = original.rightVariable,
        literalController = TextEditingController(text: original.literalController.text),
        leftParenController = TextEditingController(text: original.leftParenController.text),
        rightParenController = TextEditingController(text: original.rightParenController.text);

  _ComparisonRow clone() => _ComparisonRow._clone(this);

  void dispose() {
    literalController.dispose();
    leftParenController.dispose();
    rightParenController.dispose();
  }
}
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<Map<String, dynamic>?> showDecisionNodeDialog(
    BuildContext context, {
      required List<Map<String, String>> variables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DecisionNodeDialog(variables: variables),
  );
}

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
  bool _attemptedSubmit = false;

  late _ComparisonRow _simpleRow;
  final List<_ComparisonRow> _advancedRows = [];
  final List<String> _connectors = [];

  static const _opsNumeric = ['=', '!=', '<', '<=', '>', '>='];
  static const _opsGeneric = ['=', '!='];

  @override
  void initState() {
    super.initState();
    _simpleRow = _ComparisonRow(
      leftVariable:
      widget.variables.isNotEmpty ? widget.variables.first['name'] : null,
    );
  }

  @override
  void dispose() {
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

  bool _validateForm() {
    bool isFormValid = true;
    if (_mode == _ConditionMode.simple) {
      isFormValid = _validateRow(_simpleRow);
    } else {
      if (_advancedRows.isEmpty) return false;
      for (var row in _advancedRows) {
        if (!_validateRow(row)) isFormValid = false;
      }
      if (!_areParenthesesBalanced()) isFormValid = false;
    }
    return isFormValid;
  }

  bool _validateRow(_ComparisonRow row) {
    bool isRowValid = true;
    final leftType = _varMeta(row.leftVariable)?['type'];
    if (row.leftVariable == null) {
      row.leftError = 'Scegli una variabile';
      isRowValid = false;
    } else {
      row.leftError = null;
    }
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
      // Rimozione del controllo di corrispondenza dei tipi
      if (row.rightVariable == null) {
        row.rightError = 'Scegli una variabile';
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
      case 'int':
        return int.tryParse(value) != null;
      case 'float':
      case 'double':
        return double.tryParse(value) != null;
      case 'bool':
        return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char':
        return value.length == 1 ||
            (value.length == 3 &&
                value.startsWith("'") &&
                value.endsWith("'"));
      case 'string':
        return true;
      default:
        return true;
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
      if (balance < 0) return false;
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
          leftVariable:
          widget.variables.isNotEmpty ? widget.variables.first['name'] : null));
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
      case 'char':
        return v.length == 1 ? "'$v'" : v;
      case 'string':
        return (v.startsWith('"') && v.endsWith('"'))
            ? v
            : '"${v.replaceAll('"', '\\"')}"';
      default:
        return v;
    }
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    // Costruiamo le clausole strutturate
    final rowsToBuild = _mode == _ConditionMode.simple ? [_simpleRow] : _advancedRows;
    final clauses = <Map<String, dynamic>>[];

    for (final row in rowsToBuild) {
      final leftVar = row.leftVariable!;
      final op = _normalizeOperator(row.operator);
      String rightOp;
      bool isLiteral;

      if (row.rightMode == _RightHandMode.literal) {
        final type = _varMeta(row.leftVariable)?['type'] ?? 'string';
        rightOp = _normalizedLiteral(type, row.literalController.text);
        isLiteral = true;
      } else {
        rightOp = row.rightVariable!;
        isLiteral = false;
      }

      clauses.add({
        'leftOperand': leftVar,
        'operator': op,
        'rightOperand': rightOp,
        'isRightLiteral': isLiteral,
      });
    }

    // Determiniamo il connettore logico
    String logicalJoin = 'AND';
    if (_mode == _ConditionMode.advanced && _connectors.isNotEmpty) {
      // Assumiamo che tutti i connettori siano dello stesso tipo
      // (se l'utente vuole mescolare AND/OR, dovrebbe usare le parentesi)
      logicalJoin = _connectors.first;
    }

    // Costruiamo anche la stringa condition per il text del nodo
    final condition = _buildExpression();

    Navigator.of(context).pop({
      'text': condition,
      'clauses': clauses,
      'logicalJoin': logicalJoin,
    });
  }

  /// Normalizza gli operatori dal formato dialogo a quello standard
  String _normalizeOperator(String op) {
    switch (op) {
      case '=':
        return '==';
      case '!=':
        return '!=';
      case '<':
        return '<';
      case '<=':
        return '<=';
      case '>':
        return '>';
      case '>=':
        return '>=';
      default:
        return op;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final expressionPreview = _buildExpression();

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800),
      title: Row(children: [
        FaIcon(FontAwesomeIcons.codeBranch,
            color: theme.accentColor.defaultBrushFor(theme.brightness), size: 24),
        const SizedBox(width: 16),
        const Text('Configura Nodo Condizione'),
      ]),
      content: widget.variables.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Text(
            'Nessuna variabile definita per creare una condizione.',
            style: theme.typography.body,
          ),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solo selezione modalità (rimossa etichetta manuale).
            Align(
              alignment: Alignment.centerLeft,
              child: InfoLabel(
                label: 'Modalità di Costruzione',
                child: Row(
                  children: [
                    RadioButton(
                      checked: _mode == _ConditionMode.simple,
                      content: const Text('Semplice'),
                      onChanged: (v) {
                        if (v) {
                          setState(() => _mode = _ConditionMode.simple);
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    RadioButton(
                      checked: _mode == _ConditionMode.advanced,
                      content: const Text('Avanzata'),
                      onChanged: (v) {
                        if (v) _switchToAdvanced();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _mode == _ConditionMode.simple
                  ? _buildSimpleUI(theme)
                  : _buildAdvancedUI(theme),
            ),
            const SizedBox(height: 24),
            _buildPreview(theme, expressionPreview),
          ],
        ),
      ),
      actions: [
        Row(
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
              onPressed: _confirm,
              style: ButtonStyle(
                padding: ButtonState.all(
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleUI(FluentThemeData theme) {
    return _buildComparisonRow(_simpleRow, 0, theme, isSimpleMode: true);
  }

  Widget _buildAdvancedUI(FluentThemeData theme) {
    return Column(
      key: const ValueKey('advanced-ui'),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _advancedRows.length,
            itemBuilder: (context, index) {
              final row = _advancedRows[index];
              return _buildComparisonRow(row, index, theme);
            },
            separatorBuilder: (context, index) {
              if (index < _connectors.length) {
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 60.0),
                  child: ComboBox<String>(
                    value: _connectors[index],
                    isExpanded: true,
                    items: const [
                      ComboBoxItem(value: 'AND', child: Text('AND (entrambe vere)')),
                      ComboBoxItem(value: 'OR', child: Text('OR (almeno una vera)')),
                    ],
                    onChanged: (val) => setState(() => _connectors[index] = val!),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        if (_attemptedSubmit && !_areParenthesesBalanced())
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Errore: le parentesi non sono bilanciate.',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Button(
            onPressed: _addRow,
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              FaIcon(FontAwesomeIcons.plus, size: 16),
              SizedBox(width: 10),
              Text('Aggiungi Condizione'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(_ComparisonRow row, int index, FluentThemeData theme,
      {bool isSimpleMode = false}) {
    final leftType = _varMeta(row.leftVariable)?['type'];
    final availableOps = _opsForType(leftType);
    if (!availableOps.contains(row.operator)) row.operator = availableOps.first;

    return Column(
      key: ValueKey(row),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSimpleMode)
              SizedBox(
                width: 60,
                child:
                TextBox(controller: row.leftParenController, placeholder: '('),
              ),
            if (!isSimpleMode) const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _FormField(
                errorText: _attemptedSubmit ? row.leftError : null,
                child: ComboBox<String>(
                  value: row.leftVariable,
                  isExpanded: true,
                  items: widget.variables
                      .map((v) =>
                      ComboBoxItem(value: v['name'], child: Text(v['name']!)))
                      .toList(),
                  onChanged: (val) => setState(() {
                    row.leftVariable = val;
                    // Reset della variabile destra quando cambia quella sinistra
                    row.rightVariable = null;
                    if (_attemptedSubmit) _validateRow(row);
                  }),
                  placeholder: const Text('Variabile'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ComboBox<String>(
                value: row.operator,
                isExpanded: true,
                items: availableOps
                    .map((op) =>
                    ComboBoxItem(value: op, child: Center(child: Text(op))))
                    .toList(),
                onChanged: (val) => setState(() => row.operator = val!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _FormField(
                errorText: _attemptedSubmit ? row.rightError : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: row.rightMode == _RightHandMode.variable
                      ? ComboBox<String>(
                    key: const ValueKey('variable'),
                    value: row.rightVariable,
                    isExpanded: true,
                    // Mostra tutte le variabili disponibili
                    items: widget.variables
                        .map((v) => ComboBoxItem(
                        value: v['name'], child: Text(v['name']!)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      row.rightVariable = val;
                      if (_attemptedSubmit) _validateRow(row);
                    }),
                    placeholder: const Text('Variabile'),
                  )
                      : TextBox(
                    key: const ValueKey('literal'),
                    controller: row.literalController,
                    placeholder: 'Valore',
                    onChanged: (_) {
                      if (_attemptedSubmit) {
                        setState(() => _validateRow(row));
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!isSimpleMode)
              SizedBox(
                width: 60,
                child:
                TextBox(controller: row.rightParenController, placeholder: ')'),
              ),
            const SizedBox(width: 8),
            ToggleSwitch(
              checked: row.rightMode == _RightHandMode.variable,
              onChanged: (v) => setState(() {
                row.rightMode =
                v ? _RightHandMode.variable : _RightHandMode.literal;
                if (_attemptedSubmit) _validateRow(row);
              }),
              content: FaIcon(
                row.rightMode == _RightHandMode.variable
                    ? Icons.data_object
                    : FontAwesomeIcons.quoteLeft,
                size: 14,
              ),
            ),
            if (!isSimpleMode) ...[
              const SizedBox(width: 8),
              HoverButton(
                onPressed: () => _removeRow(index),
                builder: (context, states) => Container(
                  padding: const EdgeInsets.all(8.0),
                  color: ButtonThemeData.buttonColor(context, states),
                  child: FaIcon(
                    FontAwesomeIcons.trashCan,
                    color: theme.resources.systemFillColorCritical,
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(FluentThemeData theme, String expr) {
    if (expr.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.cardStrokeColorDefaultSolid,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anteprima Espressione',
              style:
              theme.typography.caption?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            expr,
            style: theme.typography.body?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final Widget child;
  final String? errorText;

  const _FormField({required this.child, this.errorText});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 2.0),
            child: Text(
              errorText!,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          )
      ],
    );
  }
}

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
    this.operator = '=',
    this.rightMode = _RightHandMode.literal,
    this.rightVariable,
  })  : literalController = TextEditingController(),
        leftParenController = TextEditingController(),
        rightParenController = TextEditingController();

  _ComparisonRow._clone(_ComparisonRow original)
      : leftVariable = original.leftVariable,
        operator = original.operator,
        rightMode = original.rightMode,
        rightVariable = original.rightVariable,
        literalController =
        TextEditingController(text: original.literalController.text),
        leftParenController =
        TextEditingController(text: original.leftParenController.text),
        rightParenController =
        TextEditingController(text: original.rightParenController.text);

  _ComparisonRow clone() => _ComparisonRow._clone(this);

  void dispose() {
    literalController.dispose();
    leftParenController.dispose();
    rightParenController.dispose();
  }
}

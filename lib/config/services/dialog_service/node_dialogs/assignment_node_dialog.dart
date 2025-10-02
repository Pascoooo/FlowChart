import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

Future<Map<String, dynamic>?> showAssignmentNodeDialog(
    BuildContext context, {
      required List<VariableDeclaration> availableVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AssignmentNodeDialog(
      availableVariables: availableVariables,
    ),
  );
}

// ============================================================================
// EXPRESSION PARSER & VALIDATOR
// ============================================================================

enum TokenType { number, variable, operator, leftParen, rightParen }

class Token {
  final TokenType type;
  final String value;
  Token(this.type, this.value);

  bool get isVariable => type == TokenType.variable;
  bool get isOperator => type == TokenType.operator;
  bool get isNumber => type == TokenType.number;
}

class ExpressionValidator {
  final List<VariableDeclaration> availableVars;

  ExpressionValidator(this.availableVars);

  List<Token>? tokenize(String expr) {
    final tokens = <Token>[];
    final regex = RegExp(r'(\d+\.?\d*)|([a-zA-Z_]\w*)|([+\-*/%])|(\()|(\))');
    final normalized = expr.replaceAll(RegExp(r'\s+'), '');
    int lastMatchEnd = 0;
    for (final match in regex.allMatches(normalized)) {
      if (match.start != lastMatchEnd) return null;
      lastMatchEnd = match.end;
      final value = match.group(0)!;
      if (match.group(1) != null) {
        tokens.add(Token(TokenType.number, value));
      } else if (match.group(2) != null) {
        tokens.add(Token(TokenType.variable, value));
      } else if (match.group(3) != null) {
        tokens.add(Token(TokenType.operator, value));
      } else if (match.group(4) != null) {
        tokens.add(Token(TokenType.leftParen, value));
      } else if (match.group(5) != null) {
        tokens.add(Token(TokenType.rightParen, value));
      }
    }
    if (lastMatchEnd != normalized.length) return null;
    return tokens;
  }

  String? validateSyntax(List<Token> tokens) {
    if (tokens.isEmpty) return 'Espressione vuota';
    int parenCount = 0;
    for (final token in tokens) {
      if (token.type == TokenType.leftParen) parenCount++;
      if (token.type == TokenType.rightParen) parenCount--;
      if (parenCount < 0) return 'Parentesi non bilanciate';
    }
    if (parenCount != 0) return 'Parentesi non bilanciate';
    for (int i = 0; i < tokens.length; i++) {
      final curr = tokens[i];
      final prev = i > 0 ? tokens[i - 1] : null;
      final next = i < tokens.length - 1 ? tokens[i + 1] : null;
      if (curr.isOperator) {
        if (prev == null || next == null) return 'Operatore in posizione non valida';
        if (prev.type != TokenType.number && prev.type != TokenType.variable && prev.type != TokenType.rightParen) return 'Sintassi non valida prima di "${curr.value}"';
        if (next.type != TokenType.number && next.type != TokenType.variable && next.type != TokenType.leftParen) return 'Sintassi non valida dopo "${curr.value}"';
      }
      if (curr.type == TokenType.number || curr.type == TokenType.variable) {
        if (next != null && (next.type == TokenType.number || next.type == TokenType.variable)) return 'Due valori consecutivi senza operatore';
      }
    }
    return null;
  }

  String? validateVariables(List<Token> tokens) {
    for (final token in tokens.where((t) => t.isVariable)) {
      if (!availableVars.any((v) => v.name == token.value)) {
        return 'Variabile "${token.value}" non definita';
      }
    }
    return null;
  }

  String inferType(List<Token> tokens) {
    bool hasFloat = false;
    bool hasInt = false;
    for (final token in tokens) {
      if (token.isNumber) {
        if (token.value.contains('.')) hasFloat = true;
        else hasInt = true;
      } else if (token.isVariable) {
        final varType = availableVars.firstWhere((v) => v.name == token.value).dataType;
        if (varType == 'float' || varType == 'double') hasFloat = true;
        else if (varType == 'int') hasInt = true;
      }
    }
    if (hasFloat) return 'double';
    if (hasInt) return 'int';
    return 'int';
  }

  ValidationResult validate(String expr, String targetType) {
    final trimmed = expr.trim();
    if (_isSimpleLiteral(targetType, trimmed)) return ValidationResult.success();
    if (_isValidIdentifier(trimmed)) {
      final sourceVar = availableVars.where((v) => v.name == trimmed);
      if (sourceVar.isEmpty) return ValidationResult.error('Variabile "$trimmed" non definita');
      if (!_isTypeCompatible(targetType, sourceVar.first.dataType)) return ValidationResult.error('Tipo incompatibile: "${sourceVar.first.dataType}" → "$targetType"');
      return ValidationResult.success();
    }
    if (!['int', 'float', 'double'].contains(targetType)) return ValidationResult.error('Le espressioni sono supportate solo per tipi numerici');
    final tokens = tokenize(trimmed);
    if (tokens == null) return ValidationResult.error('Caratteri non validi nell\'espressione');
    final syntaxError = validateSyntax(tokens);
    if (syntaxError != null) return ValidationResult.error(syntaxError);
    final varError = validateVariables(tokens);
    if (varError != null) return ValidationResult.error(varError);
    final resultType = inferType(tokens);
    if (!_isTypeCompatible(targetType, resultType)) return ValidationResult.error('Il risultato dell\'espressione è di tipo "$resultType", incompatibile con "$targetType"');
    return ValidationResult.success();
  }

  bool _isSimpleLiteral(String type, String value) {
    if (value.isEmpty) return false;
    switch (type) {
      case 'int': return int.tryParse(value) != null;
      case 'float': case 'double': return double.tryParse(value) != null;
      case 'bool': return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1;
      case 'string': return true;
      default: return false;
    }
  }

  bool _isValidIdentifier(String value) => RegExp(r'^[a-zA-Z_]\w*$').hasMatch(value);
  bool _isTypeCompatible(String targetType, String sourceType) {
    if (targetType == sourceType) return true;
    if ((targetType == 'float' || targetType == 'double') && sourceType == 'int') return true;
    return false;
  }
}

class ValidationResult {
  final bool isValid;
  final String? error;
  ValidationResult.success() : isValid = true, error = null;
  ValidationResult.error(this.error) : isValid = false;
}

// ============================================================================
// DIALOG
// ============================================================================

class _AssignmentNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> availableVariables;
  const _AssignmentNodeDialog({required this.availableVariables});

  @override
  State<_AssignmentNodeDialog> createState() => _AssignmentNodeDialogState();
}

class _AssignmentNodeDialogState extends State<_AssignmentNodeDialog> {
  final List<_AssignmentRowData> _assignments = [];
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _addAssignment();
  }

  @override
  void dispose() {
    for (final a in _assignments) {
      a.dispose();
    }
    super.dispose();
  }

  void _addAssignment() => setState(() => _assignments.add(_AssignmentRowData()));

  void _removeAssignment(int i) {
    setState(() {
      _assignments[i].dispose();
      _assignments.removeAt(i);
    });
    if (_attemptedSubmit) _validateForm();
  }

  bool _validateForm() {
    bool ok = true;
    final validator = ExpressionValidator(widget.availableVariables);

    for (final a in _assignments) {
      a.targetError = null;
      a.valueError = null;
      final targetVarName = a.target;
      if (targetVarName == null || targetVarName.trim().isEmpty) {
        a.targetError = 'Obbligatorio';
        ok = false;
        continue;
      }
      final targetVar = widget.availableVariables.where((v) => v.name == targetVarName);
      if (targetVar.isEmpty) {
        a.targetError = 'Variabile inesistente';
        ok = false;
        continue;
      }
      final expression = a.value.text.trim();
      if (expression.isEmpty) {
        a.valueError = 'Obbligatorio';
        ok = false;
        continue;
      }
      final result = validator.validate(expression, targetVar.first.dataType);
      if (!result.isValid) {
        a.valueError = result.error;
        ok = false;
      }
    }

    setState(() {});
    return ok;
  }

  String _generateAutoLabel() {
    final assignmentsText = _assignments
        .map((a) => '${a.target} = ...')
        .where((t) => t.isNotEmpty)
        .toList();
    if (assignmentsText.isEmpty) return 'Nodo Assegnazione';
    return assignmentsText.join(', ');
  }

// Dentro la classe _AssignmentNodeDialogState

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _generateAutoLabel(),
      'assignments': _assignments
          .where((a) => a.target != null && a.target!.isNotEmpty)
          .map((a) {
        return {
          'target': a.target,
          'expression': a.value.text.trim(),
        };
      })
          .toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
      content: SizedBox(
        height: 680,
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 20),
            Expanded(
              child: _buildAssignmentsSection(theme),
            ),
            const SizedBox(height: 12),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsSection(FluentThemeData theme) {
    final allAvailableVarNames = widget.availableVariables.map((d) => d.name).toList();

    return Column(
      children: [
        _buildAssignmentsHeader(theme),
        const SizedBox(height: 12),
        Expanded(
          child: allAvailableVarNames.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Nessuna variabile esistente a cui assegnare un valore.',
                style: theme.typography.caption,
                textAlign: TextAlign.center,
              ),
            ),
          )
              : _assignments.isEmpty
              ? _buildEmptyAssignments(theme)
              : ListView.builder(
            itemCount: _assignments.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAssignmentRow(i, theme, allAvailableVarNames),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.calculator, color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo Assegnazione', style: theme.typography.title),
              Text('Assegna valori o espressioni a variabili esistenti.',
                  style: theme.typography.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Assegnazioni', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: widget.availableVariables.isEmpty ? null : _addAssignment,
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.plus, size: 14),
              SizedBox(width: 6),
              Text('Aggiungi Assegnazione'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyAssignments(FluentThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text('Nessuna assegnazione aggiunta.', style: theme.typography.caption),
      ),
    );
  }

  Widget _buildAssignmentRow(int index, FluentThemeData theme, List<String> availableVarNames) {
    final a = _assignments[index];
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.grey[10]
              : theme.cardColor.withOpacity(0.4),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: InfoLabel(
                    label: 'Variabile di destinazione*',
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: a.target != null && availableVarNames.contains(a.target)
                          ? a.target
                          : null,
                      items: availableVarNames
                          .map((n) => ComboBoxItem(value: n, child: Text(n)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          a.target = val;
                          if (_attemptedSubmit) _validateForm();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: InfoLabel(
                    label: 'Espressione*',
                    child: TextBox(
                      controller: a.value,
                      placeholder: 'Es: 10, x, x + 5, (a + b) * 2',
                      onChanged: (_) {
                        if (_attemptedSubmit) _validateForm();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                    onPressed: () => _removeAssignment(index),
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 14),
                    style: ButtonStyle(
                        foregroundColor: ButtonState.resolveWith((states) {
                          final color = Colors.red.defaultBrushFor(theme.brightness);
                          return states.isHovering ? Colors.white : color;
                        }),
                        backgroundColor: ButtonState.resolveWith(
                                (states) => states.isHovering ? Colors.red : Colors.transparent)
                    )
                ),
              ],
            ),
            if (_attemptedSubmit && (a.targetError != null || a.valueError != null))
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _ErrorMessage(a.targetError ?? '')),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _ErrorMessage(a.valueError ?? '')),
                    const SizedBox(width: 12),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
          ],
        )
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

class _AssignmentRowData {
  String? target;
  final TextEditingController value = TextEditingController();

  String? targetError;
  String? valueError;

  _AssignmentRowData();

  void dispose() {
    value.dispose();
  }
}
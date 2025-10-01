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

  // Tokenizza l'espressione
  List<Token>? tokenize(String expr) {
    final tokens = <Token>[];
    final regex = RegExp(r'(\d+\.?\d*)|([a-zA-Z_]\w*)|([+\-*/%])|(\()|(\))');
    final normalized = expr.replaceAll(RegExp(r'\s+'), '');

    int lastMatchEnd = 0;
    for (final match in regex.allMatches(normalized)) {
      // Verifica che non ci siano caratteri non riconosciuti
      if (match.start != lastMatchEnd) {
        return null; // Carattere invalido trovato
      }
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

    // Verifica che l'intera stringa sia stata consumata
    if (lastMatchEnd != normalized.length) {
      return null;
    }

    return tokens;
  }

  // Valida la sintassi dell'espressione
  String? validateSyntax(List<Token> tokens) {
    if (tokens.isEmpty) return 'Espressione vuota';

    // Verifica parentesi bilanciate
    int parenCount = 0;
    for (final token in tokens) {
      if (token.type == TokenType.leftParen) parenCount++;
      if (token.type == TokenType.rightParen) parenCount--;
      if (parenCount < 0) return 'Parentesi non bilanciate';
    }
    if (parenCount != 0) return 'Parentesi non bilanciate';

    // Verifica sequenza valida di token
    for (int i = 0; i < tokens.length; i++) {
      final curr = tokens[i];
      final prev = i > 0 ? tokens[i - 1] : null;
      final next = i < tokens.length - 1 ? tokens[i + 1] : null;

      if (curr.isOperator) {
        // Un operatore non può essere il primo o l'ultimo token
        if (prev == null || next == null) {
          return 'Operatore in posizione non valida';
        }
        // Prima di un operatore ci deve essere un numero, variabile o )
        if (prev.type != TokenType.number &&
            prev.type != TokenType.variable &&
            prev.type != TokenType.rightParen) {
          return 'Sintassi non valida prima di "${curr.value}"';
        }
        // Dopo un operatore ci deve essere un numero, variabile o (
        if (next.type != TokenType.number &&
            next.type != TokenType.variable &&
            next.type != TokenType.leftParen) {
          return 'Sintassi non valida dopo "${curr.value}"';
        }
      }

      if (curr.type == TokenType.number || curr.type == TokenType.variable) {
        // Due valori consecutivi non sono permessi
        if (next != null &&
            (next.type == TokenType.number || next.type == TokenType.variable)) {
          return 'Due valori consecutivi senza operatore';
        }
      }
    }

    return null; // Sintassi valida
  }

  // Verifica che tutte le variabili esistano
  String? validateVariables(List<Token> tokens) {
    for (final token in tokens.where((t) => t.isVariable)) {
      if (!availableVars.any((v) => v.name == token.value)) {
        return 'Variabile "${token.value}" non definita';
      }
    }
    return null;
  }

  // Inferisce il tipo del risultato dell'espressione
  String inferType(List<Token> tokens) {
    bool hasFloat = false;
    bool hasInt = false;

    for (final token in tokens) {
      if (token.isNumber) {
        if (token.value.contains('.')) {
          hasFloat = true;
        } else {
          hasInt = true;
        }
      } else if (token.isVariable) {
        final varType = availableVars.firstWhere((v) => v.name == token.value).dataType;
        if (varType == 'float' || varType == 'double') {
          hasFloat = true;
        } else if (varType == 'int') {
          hasInt = true;
        }
      }
    }

    // Se ci sono float/double, il risultato è double
    if (hasFloat) return 'double';
    // Se ci sono solo int, il risultato è int
    if (hasInt) return 'int';
    // Fallback (non dovrebbe succedere)
    return 'int';
  }

  // Validazione completa dell'espressione
  ValidationResult validate(String expr, String targetType) {
    final trimmed = expr.trim();

    // Caso 1: Literal semplice
    if (_isSimpleLiteral(targetType, trimmed)) {
      return ValidationResult.success();
    }

    // Caso 2: Variabile singola
    if (_isValidIdentifier(trimmed)) {
      final sourceVar = availableVars.where((v) => v.name == trimmed);
      if (sourceVar.isEmpty) {
        return ValidationResult.error('Variabile "$trimmed" non definita');
      }
      if (!_isTypeCompatible(targetType, sourceVar.first.dataType)) {
        return ValidationResult.error(
            'Tipo incompatibile: "${sourceVar.first.dataType}" → "$targetType"'
        );
      }
      return ValidationResult.success();
    }

    // Caso 3+: Espressione complessa
    // Solo tipi numerici possono avere espressioni
    if (!['int', 'float', 'double'].contains(targetType)) {
      return ValidationResult.error(
          'Le espressioni sono supportate solo per tipi numerici'
      );
    }

    // Tokenizza
    final tokens = tokenize(trimmed);
    if (tokens == null) {
      return ValidationResult.error('Caratteri non validi nell\'espressione');
    }

    // Valida sintassi
    final syntaxError = validateSyntax(tokens);
    if (syntaxError != null) {
      return ValidationResult.error(syntaxError);
    }

    // Valida variabili
    final varError = validateVariables(tokens);
    if (varError != null) {
      return ValidationResult.error(varError);
    }

    // Inferisci tipo risultato
    final resultType = inferType(tokens);
    if (!_isTypeCompatible(targetType, resultType)) {
      return ValidationResult.error(
          'Il risultato dell\'espressione è di tipo "$resultType", incompatibile con "$targetType"'
      );
    }

    return ValidationResult.success();
  }

  bool _isSimpleLiteral(String type, String value) {
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

  bool _isValidIdentifier(String value) {
    return RegExp(r'^[a-zA-Z_]\w*$').hasMatch(value);
  }

  bool _isTypeCompatible(String targetType, String sourceType) {
    if (targetType == sourceType) return true;
    if ((targetType == 'float' || targetType == 'double') && sourceType == 'int') {
      return true;
    }
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
  final List<_AssignmentRowData> _assignments = [];
  bool _attemptedSubmit = false;
  int _currentTab = 0;

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
    for (final a in _assignments) {
      a.dispose();
    }
    super.dispose();
  }

  void _addVar() => setState(() => _vars.add(_VarRowData(type: 'int', hasInit: false)));

  void _removeVar(int i) {
    setState(() {
      final removedName = _vars[i].name.text.trim();
      _vars[i].dispose();
      _vars.removeAt(i);
      _assignments.removeWhere((a) => a.target == removedName);
    });
    if (_attemptedSubmit) _validateForm();
  }

  void _addAssignment() => setState(() => _assignments.add(_AssignmentRowData()));

  void _removeAssignment(int i) {
    setState(() {
      _assignments[i].dispose();
      _assignments.removeAt(i);
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

  bool _validateAssignments(List<VariableDeclaration> allAvailableVars) {
    bool ok = true;
    final validator = ExpressionValidator(allAvailableVars);

    for (final a in _assignments) {
      a.targetError = null;
      a.valueError = null;

      // Valida target
      if (a.target == null || a.target!.trim().isEmpty) {
        a.targetError = 'Obbligatorio';
        ok = false;
        continue;
      }

      final targetVar = allAvailableVars.where((v) => v.name == a.target);
      if (targetVar.isEmpty) {
        a.targetError = 'Variabile inesistente';
        ok = false;
        continue;
      }

      // Valida value (espressione)
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

    return ok;
  }

  bool _validateForm() {
    final names = <String, List<int>>{};
    bool isFormValid = true;

    final newlyDeclaredVars = _vars
        .where((v) => v.name.text.trim().isNotEmpty)
        .map((v) {
      final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
      return VariableDeclaration(
        name: v.name.text.trim(),
        dataType: v.type,
        defaultValue: defaultValue,
      );
    }).toList();

    final List<VariableDeclaration> allAvailableVars = [
      ...widget.existingDeclarations,
      ...newlyDeclaredVars
    ];

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

    if (!_validateAssignments(allAvailableVars)) isFormValid = false;
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
    return 'dichiarazione ${declaredNames.join(', ')}';
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _generateAutoLabel(),
      'declarations': _vars.map((v) {
        final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
        return {
          'name': v.name.text.trim(),
          'dataType': v.type,
          'defaultValue': defaultValue
        };
      }).toList(),
      'assignments': _assignments.map((a) {
        return {
          'target': a.target,
          'expression': a.value.text.trim(),
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
              child: TabView(
                currentIndex: _currentTab,
                onChanged: (i) => setState(() => _currentTab = i),
                tabs: [
                  Tab(
                    text: const Text('Dichiara'),
                    icon: const Icon(FluentIcons.variable),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildDeclarationsSection(theme),
                    ),
                  ),
                  Tab(
                    text: const Text('Assegna'),
                    icon: const Icon(FluentIcons.dependency_add),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildAssignmentsSection(theme),
                    ),
                  ),
                ],
              ),
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

  Widget _buildAssignmentsSection(FluentThemeData theme) {
    final allAvailableVarNames = {
      ...widget.existingDeclarations.map((d) => d.name),
      ..._vars.map((v) => v.name.text.trim()).where((n) => n.isNotEmpty),
    }.toList();

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
                'Dichiara una variabile nel tab "Dichiara" per poter effettuare assegnazioni.',
                style: theme.typography.caption,
                textAlign: TextAlign.center,
              ),
            ),
          )
              : _assignments.isEmpty
              ? SingleChildScrollView(child: _buildEmptyAssignments(theme))
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
        FaIcon(FontAwesomeIcons.keyboard, color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo Input', style: theme.typography.title),
              Text('Definisci nuove variabili e (facoltativo) assegna valori o espressioni.',
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
        Text('Variabili da Dichiarare', style: theme.typography.subtitle),
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

  Widget _buildAssignmentsHeader(FluentThemeData theme) {
    final allAvailableVars = {
      ...widget.existingDeclarations.map((d) => d.name),
      ..._vars.map((v) => v.name.text.trim()).where((n) => n.isNotEmpty)
    };
    return Row(
      children: [
        Text('Assegnazioni (opzionale)', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: allAvailableVars.isEmpty ? null : _addAssignment,
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



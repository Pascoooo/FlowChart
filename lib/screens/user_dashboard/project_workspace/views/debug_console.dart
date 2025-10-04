import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 🖥️ Console Interattiva stile Terminale per il Debug Mode
class DebugConsole extends StatefulWidget {
  final FlowNode currentNode;
  final String flowchartId;
  final dynamic projectRepo;
  final List<VariableDeclaration> allVariables;
  final VoidCallback onCommandExecuted;

  const DebugConsole({
    super.key,
    required this.currentNode,
    required this.flowchartId,
    required this.projectRepo,
    required this.allVariables,
    required this.onCommandExecuted,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final List<ConsoleEntry> _history = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isWaitingForInput = false;
  String? _currentPrompt;
  String? _currentVariable;
  Map<String, dynamic> _pendingValues = {};
  List<String> _variablesQueue = [];

  @override
  void initState() {
    super.initState();
    _initializeForNode();

    // Auto-focus sull'input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se il nodo è cambiato, reinizializza
    if (widget.currentNode.id != oldWidget.currentNode.id) {
      _initializeForNode();
    }
  }

  void _initializeForNode() {
    _history.clear();
    _pendingValues.clear();
    _variablesQueue.clear();
    _isWaitingForInput = false;

    setState(() {
      _addSystemMessage('=== ${widget.currentNode.text.toUpperCase()} ===');
      _addSystemMessage('Tipo: ${widget.currentNode.kind.name.toUpperCase()}');
      _addSystemMessage('');

      if (widget.currentNode is AssignmentNode) {
        final node = widget.currentNode as AssignmentNode;
        _addInfoMessage('Sintassi: {variabile} per usare valori esistenti');
        _addInfoMessage('Esempio: {prezzo} * 1.22');
        _addSystemMessage('');

        _variablesQueue = node.assignments.map((a) => a.target).toList();
        _promptNextVariable();
      } else if (widget.currentNode is OutputNode) {
        final node = widget.currentNode as OutputNode;
        _addInfoMessage('Template: ${node.template}');
        _addInfoMessage('Sintassi: {variabile} per usare valori esistenti');
        _addSystemMessage('');

        _variablesQueue = node.variables.map((v) => v.name).toList();
        _promptNextVariable();
      }
    });
  }

  void _promptNextVariable() {
    if (_variablesQueue.isEmpty) {
      _finalizeExecution();
      return;
    }

    final varName = _variablesQueue.removeAt(0);
    _currentVariable = varName;

    final varDecl = widget.allVariables.firstWhere(
      (v) => v.name == varName,
      orElse: () => VariableDeclaration(name: varName, dataType: 'string'),
    );

    _currentPrompt = '$varName (${varDecl.dataType})';
    _isWaitingForInput = true;

    setState(() {
      _addPrompt(_currentPrompt!);
    });

    _scrollToBottom();
  }

  Future<void> _finalizeExecution() async {
    _isWaitingForInput = false;

    if (_pendingValues.isEmpty) {
      _addErrorMessage('Nessun valore da salvare');
      return;
    }

    try {
      // Salva i valori in sessione
      await widget.projectRepo.updateDebugVariables(
        projectId: widget.flowchartId,
        variables: _pendingValues,
      );

      // Se è un output, renderizza il template
      if (widget.currentNode is OutputNode) {
        final outputNode = widget.currentNode as OutputNode;
        final allVars = await widget.projectRepo.getDebugVariables(
          projectId: widget.flowchartId,
        );

        final rendered = _renderTemplate(outputNode.template, allVars);
        _addOutputMessage(rendered);
      }

      _addSuccessMessage('✓ Operazione completata');
      _addSystemMessage('');
      _addInfoMessage('Usa il pulsante "Avanti" per continuare');

      widget.onCommandExecuted();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
    }

    setState(() {});
    _scrollToBottom();
  }

  Future<void> _handleInput(String input) async {
    if (!_isWaitingForInput || _currentVariable == null) return;

    final trimmedInput = input.trim();

    // Aggiungi l'input alla history
    _addUserInput(trimmedInput);
    _inputController.clear();

    if (trimmedInput.isEmpty) {
      _addErrorMessage('Input vuoto non valido');
      _addPrompt(_currentPrompt!);
      setState(() {});
      return;
    }

    // Risolvi il valore
    try {
      final resolved = await _resolveValue(trimmedInput, _currentVariable!);

      if (resolved.error != null) {
        _addErrorMessage(resolved.error!);
        _addPrompt(_currentPrompt!);
        setState(() {});
        return;
      }

      // Converti nel tipo corretto
      final varDecl = widget.allVariables.firstWhere(
        (v) => v.name == _currentVariable!,
        orElse: () => VariableDeclaration(name: _currentVariable!, dataType: 'string'),
      );

      final convertedValue = _convertResolvedValue(resolved.value, varDecl.dataType);
      _pendingValues[_currentVariable!] = convertedValue;

      _addSuccessMessage('✓ ${ _currentVariable!} = $convertedValue');

      // Passa alla prossima variabile
      _promptNextVariable();
    } catch (e) {
      _addErrorMessage('Errore: ${e.toString()}');
      _addPrompt(_currentPrompt!);
    }

    setState(() {});
    _scrollToBottom();
  }

  Future<ResolvedValue> _resolveValue(String input, String targetVarName) async {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      return ResolvedValue.error('Input vuoto');
    }

    final sessionVars = await widget.projectRepo.getDebugVariables(
      projectId: widget.flowchartId,
    );

    // Verifica se contiene riferimenti a variabili {nome}
    final varPattern = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
    final hasVariables = varPattern.hasMatch(trimmedInput);

    if (hasVariables) {
      final varMatches = varPattern.allMatches(trimmedInput);
      final referencedVars = <String>[];

      for (final match in varMatches) {
        final varName = match.group(1)!;
        referencedVars.add(varName);

        if (!sessionVars.containsKey(varName)) {
          return ResolvedValue.error(
            'Variabile "$varName" non trovata'
          );
        }

        final value = sessionVars[varName];
        if (value == null || (value is String && value.isEmpty)) {
          return ResolvedValue.error(
            'Variabile "$varName" non ha valore'
          );
        }
      }

      if (trimmedInput == '{${referencedVars.first}}' && referencedVars.length == 1) {
        return ResolvedValue.success(sessionVars[referencedVars.first]!, isLiteral: false);
      }

      String processedExpression = trimmedInput;

      for (final varName in referencedVars) {
        final value = sessionVars[varName];
        processedExpression = processedExpression.replaceAll(
          '{$varName}',
          value.toString(),
        );
      }

      final hasOperators = RegExp(r'[+\-*/()%]').hasMatch(processedExpression);

      if (hasOperators) {
        try {
          // Valuta espressione matematica
          final result = _evaluateMathExpression(processedExpression);
          return ResolvedValue.success(result, isLiteral: false);
        } catch (e) {
          return ResolvedValue.error('Errore valutazione: ${e.toString()}');
        }
      } else {
        return ResolvedValue.success(processedExpression, isLiteral: false);
      }
    }

    // Letterali
    final intValue = int.tryParse(trimmedInput);
    if (intValue != null) {
      return ResolvedValue.success(intValue, isLiteral: true);
    }

    final doubleValue = double.tryParse(trimmedInput);
    if (doubleValue != null) {
      return ResolvedValue.success(doubleValue, isLiteral: true);
    }

    if (trimmedInput.toLowerCase() == 'true') {
      return ResolvedValue.success(true, isLiteral: true);
    }
    if (trimmedInput.toLowerCase() == 'false') {
      return ResolvedValue.success(false, isLiteral: true);
    }

    return ResolvedValue.success(trimmedInput, isLiteral: true);
  }

  dynamic _evaluateMathExpression(String expression) {
    // Parsing semplice per espressioni matematiche
    try {
      // Rimuovi spazi
      final cleaned = expression.replaceAll(' ', '');

      // Per ora supportiamo operazioni base - in futuro si può migliorare
      if (cleaned.contains('+')) {
        final parts = cleaned.split('+');
        return parts.fold<double>(0, (sum, part) => sum + double.parse(part));
      } else if (cleaned.contains('*')) {
        final parts = cleaned.split('*');
        return parts.fold<double>(1, (product, part) => product * double.parse(part));
      }

      return double.parse(cleaned);
    } catch (e) {
      throw Exception('Espressione non valida');
    }
  }

  dynamic _convertResolvedValue(dynamic resolvedValue, String dataType) {
    switch (dataType.toLowerCase()) {
      case 'int':
      case 'integer':
        if (resolvedValue is int) return resolvedValue;
        if (resolvedValue is double) return resolvedValue.toInt();
        if (resolvedValue is String) {
          final parsed = int.tryParse(resolvedValue);
          if (parsed != null) return parsed;
        }
        throw Exception('Impossibile convertire in integer');

      case 'double':
      case 'float':
      case 'number':
        if (resolvedValue is double) return resolvedValue;
        if (resolvedValue is int) return resolvedValue.toDouble();
        if (resolvedValue is String) {
          final parsed = double.tryParse(resolvedValue);
          if (parsed != null) return parsed;
        }
        throw Exception('Impossibile convertire in number');

      case 'bool':
      case 'boolean':
        if (resolvedValue is bool) return resolvedValue;
        if (resolvedValue is String) {
          if (resolvedValue.toLowerCase() == 'true') return true;
          if (resolvedValue.toLowerCase() == 'false') return false;
        }
        throw Exception('Impossibile convertire in boolean');

      case 'string':
      default:
        return resolvedValue.toString();
    }
  }

  String _renderTemplate(String template, Map<String, dynamic> vars) {
    return template.replaceAllMapped(
      RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}'),
      (match) {
        final varName = match.group(1)!;

        if (vars.containsKey(varName)) {
          final value = vars[varName];
          if (value != null && !(value is String && value.isEmpty)) {
            return value.toString();
          }
        }

        return '{$varName}';
      },
    );
  }

  void _addSystemMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.system,
      text: text,
    ));
  }

  void _addInfoMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.info,
      text: text,
    ));
  }

  void _addPrompt(String prompt) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.prompt,
      text: prompt,
    ));
  }

  void _addUserInput(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.userInput,
      text: text,
    ));
  }

  void _addSuccessMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.success,
      text: text,
    ));
  }

  void _addErrorMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.error,
      text: text,
    ));
  }

  void _addOutputMessage(String text) {
    _history.add(ConsoleEntry(
      type: ConsoleEntryType.output,
      text: text,
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFF3F3F3),
        border: Border(
          top: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header della console
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              border: Border(
                bottom: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.terminal,
                  size: 14,
                  color: theme.accentColor.defaultBrushFor(theme.brightness),
                ),
                const SizedBox(width: 8),
                Text(
                  'Console Debug',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.resources.textFillColorPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 12),
                  onPressed: () {
                    setState(() {
                      _history.clear();
                      _addSystemMessage('Console pulita');
                    });
                  },
                ),
              ],
            ),
          ),

          // Area di output (storico)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                return _buildConsoleEntry(theme, _history[index]);
              },
            ),
          ),

          // Area di input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.cardBackgroundFillColorDefault,
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '>',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.accentColor.defaultBrushFor(theme.brightness),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: _inputController,
                    focusNode: _focusNode,
                    placeholder: _isWaitingForInput
                      ? 'Inserisci valore...'
                      : 'In attesa...',
                    enabled: _isWaitingForInput,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    onSubmitted: _handleInput,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isWaitingForInput
                    ? () => _handleInput(_inputController.text)
                    : null,
                  child: const Text('Invio'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleEntry(FluentThemeData theme, ConsoleEntry entry) {
    Color textColor;
    IconData? icon;
    String prefix = '';

    switch (entry.type) {
      case ConsoleEntryType.system:
        textColor = theme.resources.textFillColorSecondary;
        break;
      case ConsoleEntryType.info:
        textColor = theme.accentColor.defaultBrushFor(theme.brightness);
        icon = FontAwesomeIcons.circleInfo;
        prefix = 'ℹ';
        break;
      case ConsoleEntryType.prompt:
        textColor = theme.resources.textFillColorPrimary;
        prefix = '?';
        break;
      case ConsoleEntryType.userInput:
        textColor = theme.brightness == Brightness.dark
          ? Colors.white
          : Colors.black;
        prefix = '>';
        break;
      case ConsoleEntryType.success:
        textColor = Colors.green;
        break;
      case ConsoleEntryType.error:
        textColor = Colors.red;
        prefix = '✗';
        break;
      case ConsoleEntryType.output:
        textColor = theme.brightness == Brightness.dark
          ? const Color(0xFF4EC9B0)
          : const Color(0xFF008080);
        prefix = '▶';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            if (prefix.isNotEmpty)
              TextSpan(
                text: '$prefix ',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            TextSpan(
              text: entry.text,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ConsoleEntryType {
  system,
  info,
  prompt,
  userInput,
  success,
  error,
  output,
}

class ConsoleEntry {
  final ConsoleEntryType type;
  final String text;

  ConsoleEntry({
    required this.type,
    required this.text,
  });
}

class ResolvedValue {
  final dynamic value;
  final bool isLiteral;
  final String? error;

  ResolvedValue.success(this.value, {this.isLiteral = false}) : error = null;
  ResolvedValue.error(this.error) : value = null, isLiteral = false;
}


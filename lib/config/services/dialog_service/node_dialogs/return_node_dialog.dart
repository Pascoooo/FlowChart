import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

/// Dialog per configurare un nodo Return
Future<Map<String, dynamic>?> showReturnNodeDialog(
  BuildContext context, {
  required List<VariableDeclaration> availableVariables,
  String? initialExpression,
  FlowchartSignature? signature, // REQUISITO: Riceve la signature
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _ReturnNodeDialog(
      availableVariables: availableVariables,
      initialExpression: initialExpression,
      signature: signature, // REQUISITO: Passa la signature al widget
    ),
  );
}

class _ReturnNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> availableVariables;
  final String? initialExpression;
  final FlowchartSignature? signature; // REQUISITO: Riceve la signature

  const _ReturnNodeDialog({
    required this.availableVariables,
    this.initialExpression,
    this.signature, // REQUISITO: Riceve la signature
  });

  @override
  State<_ReturnNodeDialog> createState() => _ReturnNodeDialogState();
}

class _ReturnNodeDialogState extends State<_ReturnNodeDialog> {
  late TextEditingController _expressionController;
  bool _attemptedSubmit = false;
  late bool _isVoidFunction;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _expressionController = TextEditingController(
      text: widget.initialExpression ?? '',
    );
    // Determina se la funzione è void (o se la signature non è disponibile, default a void)
    _isVoidFunction = widget.signature?.returnType == 'void' || widget.signature == null;
  }

  @override
  void dispose() {
    _expressionController.dispose();
    super.dispose();
  }

  // REQUISITO: Valida l'espressione di ritorno
  bool _validateExpression(String expression) {
    if (expression.isEmpty) return true; // Gestito dal controllo obbligatorio

    final variableNames = widget.availableVariables.map((v) => v.name).toSet();
    // Estrae potenziali nomi di variabili (parole alfanumeriche con underscore)
    final potentialVars = RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*')
        .allMatches(expression)
        .map((m) => m.group(0)!)
        // Esclude numeri e parole chiave booleane
        .where((name) => num.tryParse(name) == null && name != 'true' && name != 'false')
        .toSet();

    final invalidVars = potentialVars.where((v) => !variableNames.contains(v)).toList();

    if (invalidVars.isNotEmpty) {
      setState(() {
        _validationError = 'Variabili non definite: ${invalidVars.join(', ')}';
      });
      return false;
    }

    setState(() => _validationError = null);
    return true;
  }

  void _confirm() {
    setState(() {
      _attemptedSubmit = true;
      _validationError = null;
    });

    // Se la funzione non è void, l'espressione è obbligatoria
    if (!_isVoidFunction && _expressionController.text.trim().isEmpty) {
      return; // Blocca l'invio
    }

    // REQUISITO: Esegui la validazione dell'espressione
    if (!_isVoidFunction && !_validateExpression(_expressionController.text.trim())) {
      return; // Blocca l'invio se ci sono variabili non valide
    }

    final expression = !_isVoidFunction ? _expressionController.text.trim() : null;

    Navigator.of(context).pop({
      'returnExpression': expression,
      'text': expression != null && expression.isNotEmpty
          ? 'Return $expression'
          : 'Return',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: const Text('Configura Nodo Return'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isVoidFunction)
              const Text(
                'Questo sottoprogramma è di tipo "void", quindi il nodo Return non restituirà alcun valore.',
                style: TextStyle(fontSize: 13),
              )
            else
              Text(
                'Questo sottoprogramma deve restituire un valore di tipo "${widget.signature!.returnType.toUpperCase()}".',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 16),

            if (!_isVoidFunction) ...[
              InfoLabel(
                label: 'Espressione di ritorno *',
                child: TextBox(
                  controller: _expressionController,
                  placeholder: 'es. risultato, a + b, count * 2',
                  autofocus: true,
                  onChanged: (_) => setState(() {
                    _attemptedSubmit = false;
                    _validationError = null;
                  }),
                ),
              ),
              if (_attemptedSubmit && _expressionController.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Questo campo è obbligatorio per una funzione non-void.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              if (widget.availableVariables.isNotEmpty) ...[
                Text(
                  'Variabili disponibili:',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.inactiveColor,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.availableVariables.map((v) {
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          final current = _expressionController.text;
                          _expressionController.text =
                              current.isEmpty ? v.name : '$current ${v.name}';
                          _expressionController.selection = TextSelection.collapsed(
                            offset: _expressionController.text.length,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.accentColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${v.name} (${v.dataType})',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.accentColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

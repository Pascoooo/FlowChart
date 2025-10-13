import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

/// Dialog per configurare un nodo Return
Future<Map<String, dynamic>?> showReturnNodeDialog(
  BuildContext context, {
  required List<VariableDeclaration> availableVariables,
  String? initialExpression,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => _ReturnNodeDialog(
      availableVariables: availableVariables,
      initialExpression: initialExpression,
    ),
  );
}

class _ReturnNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> availableVariables;
  final String? initialExpression;

  const _ReturnNodeDialog({
    required this.availableVariables,
    this.initialExpression,
  });

  @override
  State<_ReturnNodeDialog> createState() => _ReturnNodeDialogState();
}

class _ReturnNodeDialogState extends State<_ReturnNodeDialog> {
  late TextEditingController _expressionController;
  bool _hasReturnValue = false;

  @override
  void initState() {
    super.initState();
    _expressionController = TextEditingController(
      text: widget.initialExpression ?? '',
    );
    _hasReturnValue = widget.initialExpression != null &&
                      widget.initialExpression!.isNotEmpty;
  }

  @override
  void dispose() {
    _expressionController.dispose();
    super.dispose();
  }

  void _confirm() {
    final expression = _hasReturnValue ? _expressionController.text.trim() : null;

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
            const Text(
              'Il nodo Return termina l\'esecuzione del sottoprogramma e '
              'restituisce il controllo al chiamante.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            Checkbox(
              checked: _hasReturnValue,
              onChanged: (value) {
                setState(() {
                  _hasReturnValue = value ?? false;
                  if (!_hasReturnValue) {
                    _expressionController.clear();
                  }
                });
              },
              content: const Text('Restituisci un valore'),
            ),

            if (_hasReturnValue) ...[
              const SizedBox(height: 12),
              InfoLabel(
                label: 'Espressione di ritorno',
                child: TextBox(
                  controller: _expressionController,
                  placeholder: 'es. risultato, a + b, count * 2',
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 8),

              if (widget.availableVariables.isNotEmpty) ...[
                const SizedBox(height: 8),
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
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'ℹ️ Per funzioni void, il nodo Return non restituisce alcun valore.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.inactiveColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
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


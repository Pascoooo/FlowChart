// file: lib/config/services/dialog_service/node_dialogs/assignment_node_dialog.dart
import 'package:debug_repository/debug_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


/// Mostra il dialog di configurazione per un nodo Assignment.
Future<Map<String, dynamic>?> showAssignmentNodeDialog(
    BuildContext context, {
      required List<VariableDeclaration> availableVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AssignmentNodeDialog(availableVariables: availableVariables),
  );
}

class _AssignmentNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> availableVariables;
  const _AssignmentNodeDialog({required this.availableVariables});

  @override
  State<_AssignmentNodeDialog> createState() => _AssignmentNodeDialogState();
}

class _AssignmentNodeDialogState extends State<_AssignmentNodeDialog> {
  final _labelController = TextEditingController();
  final List<_AssignmentRowData> _assignments = [];
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    if (widget.availableVariables.isNotEmpty) {
      _addAssignment();
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
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

  /// **MODIFICA 1: Funzione che filtra le variabili per una data riga.**
  /// Esclude quelle già selezionate nelle ALTRE righe.
  List<VariableDeclaration> _getFilteredVariablesForRow(int currentRowIndex) {
    // Trova tutti i target già selezionati nelle altre righe
    final selectedInOtherRows = <String>{};
    for (int i = 0; i < _assignments.length; i++) {
      if (i == currentRowIndex) continue; // Salta la riga corrente
      final assignment = _assignments[i];
      if (assignment.selectedVariable != null) {
        selectedInOtherRows.add(assignment.selectedVariable!);
      }
    }
    // Filtra la lista originale e la restituisce
    return widget.availableVariables
        .where((variable) => !selectedInOtherRows.contains(variable.name))
        .toList();
  }

  bool _validateValue(String type, String value) {
    if (value.isEmpty) return false;
    switch (type.toLowerCase()) {
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
    if (_assignments.isEmpty) return false;
    final selectedVars = <String, List<int>>{};
    bool isFormValid = true;

    for (var i = 0; i < _assignments.length; i++) {
      final a = _assignments[i];
      a.variableError = null;
      a.valueError = null;

      // Validazione variabile selezionata
      if (a.selectedVariable == null) {
        a.variableError = 'Seleziona variabile';
        isFormValid = false;
      } else {
        selectedVars.putIfAbsent(a.selectedVariable!, () => []).add(i);
      }

      // Validazione valore/espressione SOLO se hasInit è true
      if (a.hasInit) {
        final value = a.useExpression
            ? a.expressionController.text.trim()
            : a.valueController.text.trim();

        if (value.isEmpty) {
          a.valueError = 'Obbligatorio';
          isFormValid = false;
        } else {
          if (a.useExpression) {
            final result = ExpressionParser.validate(
              value,
              widget.availableVariables.map((v) => v.name).toList(),
            );
            if (!result.isValid) {
              a.valueError = result.errorMessage;
              isFormValid = false;
            }
          } else {
            final targetVar = widget.availableVariables.firstWhere(
                  (v) => v.name == a.selectedVariable,
              orElse: () => VariableDeclaration(
                name: '',
                dataType: 'string',
                scope: VariableScope.local,
              ),
            );
            if (!_validateValue(targetVar.dataType, value)) {
              a.valueError = 'Valore non valido';
              isFormValid = false;
            }
          }
        }
      }
      // Se hasInit è false, non validare il valore (è opzionale)
    }

    // Validazione variabili duplicate
    selectedVars.forEach((varName, indices) {
      if (indices.length > 1) {
        isFormValid = false;
        for (var index in indices) {
          _assignments[index].variableError = 'Già assegnata';
        }
      }
    });

    setState(() {});
    return isFormValid;
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    final assignmentsList = _assignments.map((a) {
      String? expression;
      if (a.hasInit) {
        expression = a.useExpression
            ? a.expressionController.text.trim()
            : a.valueController.text.trim();
      }

      return {
        'target': a.selectedVariable!,
        'expression': (expression ?? '').trim(),
      };
    }).toList();

    final summary = assignmentsList
        .map((a) {
          final expr = (a['expression'] as String).trim();
          final tgt = a['target'] as String;
          return expr.isNotEmpty ? '$tgt = $expr' : tgt;
        })
        .join('; ');

    Navigator.of(context).pop({
      'text': _labelController.text.trim().isEmpty ? summary : _labelController.text.trim(),
      'assignments': assignmentsList,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasVariables = widget.availableVariables.isNotEmpty;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 750),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 20),
            if (!hasVariables) _buildNoVariablesInfo(theme),
            if (hasVariables) ...[
              InfoLabel(
                label: 'Etichetta Nodo (opzionale)',
                child: TextBox(
                  controller: _labelController,
                  placeholder: 'Es. Calcola Risultato',
                ),
              ),
              const SizedBox(height: 24),
              _buildAssignmentHeader(theme),
              const SizedBox(height: 16),
              Expanded(
                child: _assignments.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  shrinkWrap: true,
                  itemCount: _assignments.length,
                  itemBuilder: (_, i) => _buildAssignmentRow(i, theme),
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildDialogActions(hasVariables),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.equals, color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo Assegnazione', style: theme.typography.title),
              Text(
                'Le variabili possono essere assegnate in configurazione o a runtime durante il debug.',
                style: theme.typography.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoVariablesInfo(FluentThemeData theme) {
    return Expanded(
      child: Center(
        child: InfoBar(
          title: const Text('Nessuna variabile disponibile'),
          content: const Text('Crea prima delle variabili nel progetto.'),
          severity: InfoBarSeverity.info,
          isLong: true,
        ),
      ),
    );
  }

  Widget _buildAssignmentHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Assegnazioni', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: _addAssignment,
          style: ButtonStyle(
            padding: ButtonState.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          ),
          child: const Row(
            children: [
              Icon(FluentIcons.add, size: 16),
              SizedBox(width: 8),
              Text('Aggiungi'),
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
          Icon(FluentIcons.info, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text('Nessuna assegnazione definita', style: theme.typography.bodyLarge),
          const SizedBox(height: 4),
          Text('Aggiungi la prima assegnazione.', style: theme.typography.caption),
        ],
      ),
    );
  }

  Widget _buildAssignmentRow(int index, FluentThemeData theme) {
    final a = _assignments[index];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? Colors.grey[20]
            : theme.cardColor.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: InfoLabel(
                  label: 'Variabile *',
                  child: ComboBox<String>(
                    isExpanded: true,
                    placeholder: const Text('Seleziona...'),
                    value: a.selectedVariable,
                    /// **MODIFICA 2: Il ComboBox ora usa la lista filtrata.**
                    items: _getFilteredVariablesForRow(index).map((v) {
                      return ComboBoxItem(
                        value: v.name,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                v.dataType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(v.name, style: const TextStyle(fontFamily: 'Consolas, Monaco, monospace')),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        a.selectedVariable = val;
                        a.expressionController.clear();
                        a.valueController.clear();
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: AnimatedOpacity(
                  opacity: a.hasInit ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: InfoLabel(
                    label: a.useExpression ? 'Espressione *' : 'Valore *',
                    child: TextBox(
                      controller: a.useExpression ? a.expressionController : a.valueController,
                      enabled: a.hasInit,
                      placeholder: a.useExpression
                          ? 'Es. x + 10 * y'
                          : (a.selectedVariable != null ? _getHintForVariable(a.selectedVariable!) : ''),
                      prefix: a.hasInit
                          ? Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: FaIcon(
                          a.useExpression ? FontAwesomeIcons.calculator : FontAwesomeIcons.hashtag,
                          size: 14,
                          color: theme.typography.body?.color?.withValues(alpha: 0.5),
                        ),
                      )
                          : null,
                      style: const TextStyle(fontFamily: 'Consolas, Monaco, monospace', fontSize: 14),
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
                    checked: a.hasInit,
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        a.hasInit = val;
                        if (!val) {
                          a.expressionController.clear();
                          a.valueController.clear();
                        }
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeAssignment(index),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    final color = Colors.red.defaultBrushFor(theme.brightness);
                    return states.isHovered ? Colors.white : color;
                  }),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.isHovered ? Colors.red : Colors.transparent;
                  }),
                ),
                icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
              ),
            ],
          ),
          if (a.hasInit) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(flex: 3),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: ToggleSwitch(
                    checked: a.useExpression,
                    onChanged: (val) => setState(() {
                      a.useExpression = val;
                      if (val) {
                        a.valueController.clear();
                      } else {
                        a.expressionController.clear();
                      }
                      if (_attemptedSubmit) _validateForm();
                    }),
                    content: Text(
                      a.useExpression ? 'Espressione matematica' : 'Valore diretto',
                      style: theme.typography.body,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Spacer(flex: 1),
                const SizedBox(width: 12),
                const SizedBox(width: 40),
              ],
            ),
          ],
          if (_attemptedSubmit && (a.variableError != null || a.valueError != null))
            _buildErrorMessages(a),
        ],
      ),
    );
  }

  String _getHintForVariable(String variableName) {
    final variable = widget.availableVariables.firstWhere(
          (v) => v.name == variableName,
      orElse: () => VariableDeclaration(name: '', dataType: 'string', scope: VariableScope.local),
    );

    switch (variable.dataType.toLowerCase()) {
      case 'int':
        return 'Es. 42';
      case 'float':
      case 'double':
        return 'Es. 3.14';
      case 'bool':
        return 'Es. true';
      case 'char':
        return 'Es. A';
      case 'string':
        return 'Es. "Testo"';
      default:
        return '';
    }
  }

  Widget _buildErrorMessages(_AssignmentRowData a) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _ErrorMessage(a.variableError ?? '')),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: _ErrorMessage(a.valueError ?? '')),
          const SizedBox(width: 16),
          const Spacer(flex: 1),
          const SizedBox(width: 12),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDialogActions(bool hasVariables) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
          child: const Text('Annulla'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: hasVariables ? _confirm : null,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
          ),
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
    return Text(
      message,
      style: theme.typography.caption?.copyWith(color: Colors.red.defaultBrushFor(theme.brightness)),
    );
  }
}

class _AssignmentRowData {
  final expressionController = TextEditingController();
  final valueController = TextEditingController();
  String? selectedVariable;
  bool hasInit = false;
  bool useExpression = false;
  String? variableError;
  String? valueError;

  void dispose() {
    expressionController.dispose();
    valueController.dispose();
  }
}

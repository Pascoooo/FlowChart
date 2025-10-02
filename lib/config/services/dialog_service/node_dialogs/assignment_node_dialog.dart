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
// NOTA: Questa sezione non è più utilizzata da questo dialogo, ma potrebbe
// servire per altri nodi (es. Decisione). La lasciamo per compatibilità futura.
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
  // ... (codice invariato, non più usato qui)
}

class ValidationResult {
  // ... (codice invariato, non più usato qui)
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
  // MODIFICATO: La lista ora contiene solo i dati necessari
  final List<_AssignmentRowData> _assignments = [];
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    // Aggiunge una riga di assegnazione vuota all'inizio
    if (widget.availableVariables.isNotEmpty) {
      _addAssignment();
    }
  }

  void _addAssignment() => setState(() => _assignments.add(_AssignmentRowData()));

  void _removeAssignment(int i) {
    setState(() {
      _assignments.removeAt(i);
    });
    if (_attemptedSubmit) _validateForm();
  }

  // MODIFICATO: Validazione molto più semplice
  bool _validateForm() {
    bool isFormValid = true;
    for (final assignment in _assignments) {
      assignment.targetError = null; // Resetta l'errore
      if (assignment.target == null || assignment.target!.trim().isEmpty) {
        assignment.targetError = 'Selezionare una variabile';
        isFormValid = false;
      }
    }
    setState(() {});
    return isFormValid;
  }

  // MODIFICATO: L'etichetta ora riflette la nuova funzione
  String _generateAutoLabel() {
    final targets = _assignments
        .map((a) => a.target)
        .where((t) => t != null && t.isNotEmpty)
        .toList();

    if (targets.isEmpty) return 'Input a Runtime';
    return 'Input per: ${targets.join(', ')}';
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _generateAutoLabel(),
      'assignments': _assignments
          .where((a) => a.target != null && a.target!.isNotEmpty)
          .map((a) {
        // ✨ LOGICA CHIAVE ✨
        // Non salviamo più un'espressione, ma un segnaposto speciale.
        // Il motore di debug interpreterà "?" come "fermati e chiedi un input".
        return Assignment(
          target: a.target!,
          expression: '?', // Segnaposto per l'input a runtime
        ).toMap();
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
      content: SizedBox(
        height: 520,
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

  Widget _buildHeader(FluentThemeData theme) {
    return Row(
      children: [
        FaIcon(FontAwesomeIcons.keyboard, color: theme.accentColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Input a Runtime', style: theme.typography.title),
              Text('Seleziona le variabili a cui verrà assegnato un valore durante il debug.',
                  style: theme.typography.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsSection(FluentThemeData theme) {
    return Column(
      children: [
        _buildAssignmentsHeader(theme),
        const SizedBox(height: 12),
        Expanded(
          child: widget.availableVariables.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Nessuna variabile definita. Aggiungi prima un nodo di Input.',
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
              child: _buildAssignmentRow(i, theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Variabili da Valorizzare', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: widget.availableVariables.isEmpty ? null : _addAssignment,
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.plus, size: 14),
              SizedBox(width: 6),
              Text('Aggiungi Variabile'),
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
        child: Text('Nessuna variabile aggiunta.', style: theme.typography.caption),
      ),
    );
  }

  // MODIFICATO: La riga ora contiene solo la ComboBox di selezione
  Widget _buildAssignmentRow(int index, FluentThemeData theme) {
    final assignmentData = _assignments[index];
    final availableVarNames = widget.availableVariables.map((v) => v.name).toList();

    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light ? Colors.grey[10] : theme.cardColor.withOpacity(0.4),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InfoLabel(
                    label: 'Variabile di destinazione*',
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: assignmentData.target,
                      items: availableVarNames
                          .map((name) => ComboBoxItem(value: name, child: Text(name)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          assignmentData.target = value;
                          if (_attemptedSubmit) _validateForm();
                        });
                      },
                      placeholder: const Text('Seleziona una variabile'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 22.0), // Allinea con i campi
                  child: IconButton(
                    onPressed: () => _removeAssignment(index),
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 14),
                    style: ButtonStyle(
                        foregroundColor: ButtonState.resolveWith((states) {
                          final color = Colors.red.defaultBrushFor(theme.brightness);
                          return states.isHovering ? Colors.white : color;
                        }),
                        backgroundColor: ButtonState.resolveWith(
                                (states) => states.isHovering ? Colors.red : Colors.transparent)
                    ),
                  ),
                ),
              ],
            ),
            if (_attemptedSubmit && assignmentData.targetError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 2.0),
                child: _ErrorMessage(assignmentData.targetError!),
              ),
          ],
        ));
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

// MODIFICATO: Classe di supporto dati ultra-semplificata
class _AssignmentRowData {
  String? target;
  String? targetError;

  _AssignmentRowData();
}
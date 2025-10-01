// file: lib/config/services/dialog_service/node_dialogs/output_node_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<Map<String, dynamic>?> showOutputNodeDialog(
    BuildContext context, {
      required List<VariableDeclaration> availableVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OutputNodeDialog(variables: availableVariables),
  );
}

class _OutputNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> variables;
  const _OutputNodeDialog({required this.variables});

  @override
  State<_OutputNodeDialog> createState() => _OutputNodeDialogState();
}

class _OutputNodeDialogState extends State<_OutputNodeDialog> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _insertVariable(String variableName) {
    final textToInsert = '{{$variableName}}';
    final currentText = _messageController.text;
    final selection = _messageController.selection;
    final newText =
    currentText.replaceRange(selection.start, selection.end, textToInsert);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: selection.start + textToInsert.length),
    );
  }

  String _buildAutoLabel(String template) {
    if (template.isEmpty) return "stampa ''";
    var cleaned = template.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 48) cleaned = '${cleaned.substring(0, 48)}…';
    cleaned = cleaned.replaceAll("'", r"\'");
    return "stampa '$cleaned'";
  }

  void _onConfirm() {
    final raw = _messageController.text.trim();
    if (raw.isNotEmpty) {
      final RegExp regex = RegExp(r'\{\{(\w+)\}\}');
      final matches = regex.allMatches(raw);
      final usedVariables = matches.map((m) => m.group(1)!).toSet().toList();

      final result = {
        'text': _buildAutoLabel(raw),     // etichetta autogenerata
        'template': raw,
        'variables': usedVariables,
      };
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isValid = _messageController.text.trim().isNotEmpty;

    return Center(
      child: ContentDialog(
        constraints: const BoxConstraints(
          minWidth: 600,
          maxWidth: 700,
          minHeight: 480,
        ),
        content: Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, theme),
              const SizedBox(height: 24),
              Container(
                height: 1,
                width: double.infinity,
                color: theme.resources.dividerStrokeColorDefault,
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionLabel(
                        context,
                        'Messaggio di Output',
                        isRequired: true,
                      ),
                      const SizedBox(height: 8),
                      TextBox(
                        controller: _messageController,
                        placeholder:
                        'Es. Il risultato del calcolo è: {{risultato}}',
                        maxLines: 6,
                        style: theme.typography.body?.copyWith(
                          color: theme.typography.body?.color,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_messageController.text.trim().isNotEmpty)
                        InfoLabel(
                          label: 'Etichetta Generata',
                          child: Text(
                            _buildAutoLabel(_messageController.text.trim()),
                            style: theme.typography.caption?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildSectionLabel(context, 'Variabili Disponibili'),
                      const SizedBox(height: 8),
                      if (widget.variables.isNotEmpty) ...[
                        Text(
                          'Clicca su una variabile per inserirla nel messaggio',
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildVariableGrid(context, theme),
                      ] else
                        _buildEmptyVariablesState(context, theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Button(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isValid ? _onConfirm : null,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  child: const Text('Conferma'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FluentThemeData theme) {
    final warningColor = theme.brightness == Brightness.light
        ? const Color(0xFFD97706)
        : const Color(0xFFF59E0B);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: warningColor.withValues(alpha: 0.2),
            ),
          ),
          child: FaIcon(
            FontAwesomeIcons.terminal,
            size: 20,
            color: warningColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configura Nodo Output',
                style: theme.typography.title?.copyWith(
                  color: theme.typography.body?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Definisci il messaggio da visualizzare con variabili dinamiche.',
                style: theme.typography.body?.copyWith(
                  color: theme.typography.body?.color?.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label,
      {bool isRequired = false}) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.typography.bodyStrong?.copyWith(
            color: theme.typography.body?.color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              color: theme.brightness == Brightness.light
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFEF4444),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariableGrid(BuildContext context, FluentThemeData theme) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: widget.variables.map((variable) {
        return _VariableChip(
          variable: variable,
          onPressed: () => _insertVariable(variable.name),
          theme: theme,
        );
      }).toList(),
    );
  }

  Widget _buildEmptyVariablesState(
      BuildContext context, FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.resources.layerFillColorAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            FaIcon(
              FontAwesomeIcons.boxOpen,
              size: 24,
              color: theme.typography.body?.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Nessuna variabile disponibile',
              style: theme.typography.body?.copyWith(
                color: theme.typography.body?.color?.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Crea prima dei nodi Input per dichiarare variabili',
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VariableChip extends StatelessWidget {
  final VariableDeclaration variable;
  final VoidCallback onPressed;
  final FluentThemeData theme;

  const _VariableChip({
    required this.variable,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final isHovering = states.isHovered;
        final isPressed = states.isPressed;

        Color backgroundColor;
        Color foregroundColor;
        double elevation;
        final accent = theme.accentColor.defaultBrushFor(theme.brightness);

        if (isPressed) {
          backgroundColor = accent.withValues(alpha: 0.25);
          foregroundColor = accent;
          elevation = 0;
        } else if (isHovering) {
          backgroundColor = accent.withValues(alpha: 0.15);
          foregroundColor = accent;
          elevation = 2;
        } else {
          backgroundColor = accent.withValues(alpha: 0.10);
          foregroundColor = accent;
          elevation = 0;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.30),
            ),
            boxShadow: elevation > 0
                ? [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.10),
                offset: Offset(0, elevation),
                blurRadius: elevation * 2,
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: foregroundColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variable.dataType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: foregroundColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                variable.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

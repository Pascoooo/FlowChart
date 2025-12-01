// file: lib/config/services/dialog_service/node_dialogs/output_node_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Mostra il dialog di configurazione per un nodo Output.
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
  bool _attemptedSubmit = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      _validationError = 'Il messaggio non può essere vuoto';
      return false;
    }
    _validationError = null;
    return true;
  }

  void _insertVariable(String variableName) {
    final textToInsert = '{{$variableName}}';
    final currentText = _messageController.text;
    final selection = _messageController.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = currentText.length;
      end = currentText.length;
    }

    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    start = start.clamp(0, currentText.length);
    end = end.clamp(0, currentText.length);

    final newText = currentText.replaceRange(start, end, textToInsert);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );

    if (_attemptedSubmit) setState(() => _validateForm());
  }

  String _buildAutoLabel(String template) {
    if (template.isEmpty) return "stampa ''";
    var cleaned = template.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 48) cleaned = '${cleaned.substring(0, 48)}…';
    cleaned = cleaned.replaceAll("'", r"\'");
    return "stampa '$cleaned'";
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;

    final raw = _messageController.text.trim();
    final regex = RegExp(r'\{\{(\w+)\}\}');
    final matches = regex.allMatches(raw);
    final usedVariables = matches.map((m) => m.group(1)!).toSet().toList();

    Navigator.of(context).pop({
      'text': _buildAutoLabel(raw),
      'template': raw,
      'variables': usedVariables,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final expressionPreview = _messageController.text.trim().isNotEmpty
        ? _buildAutoLabel(_messageController.text.trim())
        : '';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
      title: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.accentColor.defaultBrushFor(theme.brightness),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const FaIcon(
                FontAwesomeIcons.terminal,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Configura Nodo Output',
                    style: theme.typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Definisci il messaggio da visualizzare con variabili dinamiche',
                    style: theme.typography.caption?.copyWith(
                      color: theme.typography.caption?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildMessageSection(theme),
              const SizedBox(height: 24),
              _buildVariablesSection(theme),
              const SizedBox(height: 24),
              if (expressionPreview.isNotEmpty)
                _buildPreview(theme, expressionPreview),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                onPressed: () => Navigator.of(context).pop(null),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                ),
                child: const Text('Annulla'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _confirm,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.isDisabled) {
                      return theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.4);
                    }
                    if (states.isHovering) {
                      return theme.accentColor.light;
                    }
                    return theme.accentColor.defaultBrushFor(theme.brightness);
                  }),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.check, size: 14, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Conferma'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Messaggio di Output *',
          style: theme.typography.bodyStrong?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextBox(
          controller: _messageController,
          placeholder: 'Es. Il risultato del calcolo è: {{risultato}}',
          maxLines: 5,
          style: theme.typography.body?.copyWith(
            fontFamily: 'Consolas, Monaco, monospace',
          ),
          onChanged: (_) {
            if (_attemptedSubmit) setState(() => _validateForm());
          },
        ),
        if (_attemptedSubmit && _validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 2.0),
            child: Text(
              _validationError!,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVariablesSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Variabili Disponibili',
          style: theme.typography.bodyStrong?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Clicca su una variabile per inserirla nel messaggio',
          style: theme.typography.caption?.copyWith(
            color: theme.typography.caption?.color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.variables
              .map((variable) => _buildVariableChip(variable, theme))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildVariableChip(VariableDeclaration variable, FluentThemeData theme) {
    return HoverButton(
      onPressed: () => _insertVariable(variable.name),
      cursor: SystemMouseCursors.click,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: states.isHovering
                ? theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.15)
                : theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variable.dataType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: theme.accentColor.defaultBrushFor(theme.brightness),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                variable.name,
                style: theme.typography.body?.copyWith(
                  fontFamily: 'Consolas, Monaco, monospace',
                  color: theme.accentColor.defaultBrushFor(theme.brightness),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview(FluentThemeData theme, String preview) {
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
          Text(
            'Anteprima Etichetta',
            style: theme.typography.caption?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            preview,
            style: theme.typography.body?.copyWith(fontFamily: 'Consolas, Monaco, monospace'),
          ),
        ],
      ),
    );
  }
}

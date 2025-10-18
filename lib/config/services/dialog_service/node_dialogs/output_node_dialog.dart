// file: lib/config/services/dialog_service/node_dialogs/output_node_dialog.dart
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Mostra il dialog di configurazione per un nodo Output.
///
/// Ritorna un [Map] con la configurazione del nodo o null se annullato.
/// Il dialog è sempre mostrato, anche se [availableVariables] è vuota.
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
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _validationError = _validateMessage(_messageController.text);
    });
  }

  String? _validateMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Il messaggio non può essere vuoto';
    }
    return null;
  }

  void _insertVariable(String variableName) {
    final textToInsert = '{{$variableName}}';
    final currentText = _messageController.text;
    final selection = _messageController.selection;

    // Gestisci selezione non valida (-1) o invertita e clamp agli estremi
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      // Nessuna selezione/caret non posizionato: inserisci alla fine
      start = currentText.length;
      end = currentText.length;
    }

    if (start > end) {
      final tmp = start; start = end; end = tmp;
    }

    // Clamp agli estremi per evitare RangeError
    if (start < 0) start = 0;
    if (end < 0) end = 0;
    if (start > currentText.length) start = currentText.length;
    if (end > currentText.length) end = currentText.length;

    final newText = currentText.replaceRange(
      start,
      end,
      textToInsert,
    );

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + textToInsert.length,
      ),
    );
  }

  String _buildAutoLabel(String template) {
    if (template.isEmpty) return "stampa ''";

    var cleaned = template.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 48) {
      cleaned = '${cleaned.substring(0, 48)}…';
    }
    cleaned = cleaned.replaceAll("'", r"\'");

    return "stampa '$cleaned'";
  }

  void _onConfirm() {
    final raw = _messageController.text.trim();

    if (_validationError != null || raw.isEmpty) {
      return;
    }

    final RegExp regex = RegExp(r'\{\{(\w+)\}\}');
    final matches = regex.allMatches(raw);
    final usedVariables = matches.map((m) => m.group(1)!).toSet().toList();

    final result = {
      'text': _buildAutoLabel(raw),
      'template': raw,
      'variables': usedVariables,
    };

    Navigator.of(context).pop(result);
  }

  void _onCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isValid = _validationError == null &&
        _messageController.text.trim().isNotEmpty;

    return ContentDialog(
      constraints: const BoxConstraints(
        minWidth: 550,
        maxWidth: 700,
        maxHeight: 680,
      ),
      content: _buildDialogContent(context, theme),
      actions: _buildDialogActions(context, theme, isValid),
    );
  }

  Widget _buildDialogContent(BuildContext context, FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 20),
          _buildDivider(theme),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageSection(theme),
                  const SizedBox(height: 20),
                  _buildVariablesSection(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    final iconColor = theme.brightness == Brightness.light
        ? const Color(0xFFD97706)
        : const Color(0xFFF59E0B);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: FaIcon(
            FontAwesomeIcons.terminal,
            size: 20,
            color: iconColor,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Definisci il messaggio da visualizzare con variabili dinamiche',
                style: theme.typography.body?.copyWith(
                  color: theme.typography.body?.color?.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(FluentThemeData theme) {
    return Container(
      height: 1,
      width: double.infinity,
      color: theme.resources.dividerStrokeColorDefault,
    );
  }

  Widget _buildMessageSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Messaggio di Output', theme, isRequired: true),
        const SizedBox(height: 10),
        TextBox(
          controller: _messageController,
          placeholder: 'Es. Il risultato del calcolo è: {{risultato}}',
          maxLines: 5,
          style: theme.typography.body?.copyWith(
            fontFamily: 'Consolas, Monaco, monospace',
            fontSize: 13,
          ),
          decoration: WidgetStateProperty.all(
            BoxDecoration(
              border: Border.all(
                color: _validationError != null
                    ? (theme.brightness == Brightness.light
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFEF4444))
                    : theme.resources.controlStrokeColorDefault,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        if (_validationError != null) ...[
          const SizedBox(height: 6),
          Text(
            _validationError!,
            style: TextStyle(
              color: theme.brightness == Brightness.light
                  ? const Color(0xFFDC2626)
                  : const Color(0xFFEF4444),
              fontSize: 12,
            ),
          ),
        ],
        if (_messageController.text.trim().isNotEmpty &&
            _validationError == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.layerFillColorAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.tag,
                  size: 12,
                  color: theme.typography.body?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Etichetta Generata',
                        style: theme.typography.caption?.copyWith(
                          fontSize: 11,
                          color: theme.typography.body?.color
                              ?.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildAutoLabel(_messageController.text.trim()),
                        style: theme.typography.body?.copyWith(
                          fontFamily: 'Consolas, Monaco, monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariablesSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Variabili Disponibili', theme),
        const SizedBox(height: 10),
        if (widget.variables.isEmpty)
          _buildEmptyVariablesInfo(theme)
        else
          _buildVariablesContent(theme),
      ],
    );
  }

  Widget _buildEmptyVariablesInfo(FluentThemeData theme) {
    return InfoBar(
      title: const Text('Nessuna variabile di output definita'),
      content: const Text(
        'Aggiungi variabili di output dal menu principale.',
      ),
      severity: InfoBarSeverity.info,
      style: InfoBarThemeData(
        decoration: (severity) => BoxDecoration(
          color: theme.resources.layerFillColorAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.accentColor.defaultBrushFor(theme.brightness)
                .withValues(alpha: 0.3),
          ),
        ),
        icon: (severity) => FontAwesomeIcons.circleInfo,
      ),
    );
  }

  Widget _buildVariablesContent(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clicca su una variabile per inserirla nel messaggio',
          style: theme.typography.caption?.copyWith(
            color: theme.typography.body?.color?.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        _buildVariableGrid(theme),
      ],
    );
  }

  Widget _buildVariableGrid(FluentThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.variables
          .map((variable) => _VariableChip(
        variable: variable,
        onPressed: () => _insertVariable(variable.name),
        theme: theme,
      ))
          .toList(),
    );
  }

  Widget _buildSectionLabel(
      String label,
      FluentThemeData theme, {
        bool isRequired = false,
      }) {
    return Row(
      children: [
        Text(
          label,
          style: theme.typography.bodyStrong?.copyWith(
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

  List<Widget> _buildDialogActions(
      BuildContext context,
      FluentThemeData theme,
      bool isValid,
      ) {
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Button(
              onPressed: _onCancel,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('Annulla'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: isValid ? _onConfirm : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text('Conferma'),
              ),
            ),
          ],
        ),
      ),
    ];
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
      cursor: SystemMouseCursors.click,
      builder: (context, states) {
        final accent = theme.accentColor.defaultBrushFor(theme.brightness);

        final backgroundColor = states.isPressed
            ? accent.withValues(alpha: 0.25)
            : states.isHovered
            ? accent.withValues(alpha: 0.15)
            : accent.withValues(alpha: 0.10);

        final borderColor = states.isPressed
            ? accent.withValues(alpha: 0.5)
            : states.isHovered
            ? accent.withValues(alpha: 0.4)
            : accent.withValues(alpha: 0.3);

        final elevation = states.isHovered && !states.isPressed ? 2.0 : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: elevation > 0
                ? [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                offset: Offset(0, elevation),
                blurRadius: elevation * 2,
                spreadRadius: 0,
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variable.dataType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accent,
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
                  color: accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
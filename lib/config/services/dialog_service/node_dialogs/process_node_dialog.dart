// dart
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Future<Map<String, dynamic>?> showProcessNodeDialog(
    BuildContext context, {
      required List<MyFile> files,
      required List<VariableDeclaration> availableVariables,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProcessNodeDialog(
      files: files,
      availableVariables: availableVariables,
    ),
  );
}

class _ProcessNodeDialog extends StatefulWidget {
  final List<MyFile> files;
  final List<VariableDeclaration> availableVariables;

  const _ProcessNodeDialog({
    required this.files,
    required this.availableVariables,
  });

  @override
  State<_ProcessNodeDialog> createState() => _ProcessNodeDialogState();
}

class _ProcessNodeDialogState extends State<_ProcessNodeDialog> {
  final _resultVariableNameController = TextEditingController();
  final List<String?> _arguments = [];
  MyFile? _selectedFile;
  String? _resultVariableType = 'void';
  bool _attemptedSubmit = false;

  @override
  void dispose() {
    _resultVariableNameController.dispose();
    super.dispose();
  }

  void _addArgument() => setState(() => _arguments.add(null));
  void _removeArgument(int index) => setState(() => _arguments.removeAt(index));

  List<String> get _availableDataTypes => [
    'string',
    'int',
    'double',
    'bool',
    'void',
  ];

  String _autoLabel() {
    if (_selectedFile == null) return "chiama ''";
    final name = _selectedFile!.name.replaceAll("'", r"\'");
    return "chiama '$name'";
  }

  void _onConfirm() {
    setState(() => _attemptedSubmit = true);
    if (_selectedFile == null) return;

    final arguments = _arguments
        .where((arg) => arg != null && arg!.isNotEmpty)
        .cast<String>()
        .toList();

    Map<String, dynamic>? resultTarget;
    final resultVarName = _resultVariableNameController.text.trim();
    if (resultVarName.isNotEmpty) {
      resultTarget = {
        'name': resultVarName,
        'type': _resultVariableType ?? 'void',
      };
    }

    Navigator.of(context).pop({
      'text': _autoLabel(), // Etichetta automatica
      'flowchartToCall': _selectedFile!.fileId,
      'arguments': arguments,
      'resultTarget': resultTarget,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final errorColor = Colors.red.defaultBrushFor(theme.brightness);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 750),
      title: _buildHeader(context),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(context, 'Flowchart da Chiamare', isRequired: true),
            const SizedBox(height: 8),
            ComboBox<MyFile>(
              isExpanded: true,
              value: _selectedFile,
              items: widget.files
                  .map((f) => ComboBoxItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedFile = val),
              placeholder: const Text('Seleziona un file da chiamare'),
            ),
            if (_attemptedSubmit && _selectedFile == null)
              _buildErrorMessage(context, 'Devi selezionare un flowchart da chiamare'),
            const SizedBox(height: 24),

            // Etichetta generata (anteprima)
            if (_selectedFile != null)
              InfoLabel(
                label: 'Etichetta Generata',
                child: Text(
                  _autoLabel(),
                  style: theme.typography.caption?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),

            const SizedBox(height: 24),
            _buildSectionLabel(context, 'Variabile per il Risultato'),
            const SizedBox(height: 8),
            Text(
              'Salva opzionalmente il risultato della chiamata in una nuova variabile.',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: InfoLabel(
                    label: 'Nome Variabile',
                    child: TextBox(
                      controller: _resultVariableNameController,
                      placeholder: 'Es. risultato_calcolo',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: InfoLabel(
                    label: 'Tipo',
                    child: ComboBox<String>(
                      isExpanded: true,
                      value: _resultVariableType,
                      items: _availableDataTypes
                          .map((type) => ComboBoxItem(
                        value: type,
                        child: Text(type.toUpperCase()),
                      ))
                          .toList(),
                      onChanged: (val) => setState(() => _resultVariableType = val),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSectionLabel(context, 'Argomenti da Passare'),
                ),
                Button(
                  onPressed: _addArgument,
                  child: Row(
                    children: const [
                      FaIcon(FontAwesomeIcons.plus, size: 14),
                      SizedBox(width: 8),
                      Text('Aggiungi'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Seleziona le variabili da passare come argomenti al flowchart chiamato.',
              style: theme.typography.caption,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              child: _arguments.isEmpty
                  ? _buildEmptyArgumentsState(context)
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: _arguments.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildArgumentItem(context, index, errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Button(
              onPressed: () => Navigator.of(context).pop(null),
              style: ButtonStyle(
                padding: ButtonState.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              child: const Text('Annulla'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _selectedFile != null ? _onConfirm : null,
              style: ButtonStyle(
                padding: ButtonState.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(
            FontAwesomeIcons.gears,
            size: 20,
            color: theme.accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configura Nodo di Processo', style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                'Imposta la chiamata ad un altro flowchart con parametri.',
                style: theme.typography.body,
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
        Text(label, style: theme.typography.bodyStrong),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              color: Colors.red.defaultBrushFor(theme.brightness),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, String message) {
    final theme = FluentTheme.of(context);
    final errorColor = Colors.red.defaultBrushFor(theme.brightness);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleExclamation,
              size: 14, color: errorColor),
          const SizedBox(width: 8),
          Text(
            message,
            style: theme.typography.caption?.copyWith(color: errorColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyArgumentsState(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.resources.layerFillColorAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(FontAwesomeIcons.listUl,
                size: 24, color: theme.inactiveBackgroundColor),
            const SizedBox(height: 12),
            Text(
              'Nessun argomento specificato',
              style: theme.typography.body
                  ?.copyWith(color: theme.inactiveColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArgumentItem(BuildContext context, int index, Color errorColor) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Row(
        children: [
          Text(
            '${index + 1}',
            style:
            theme.typography.bodyStrong?.copyWith(color: theme.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ComboBox<String>(
              isExpanded: true,
              value: _arguments[index],
              placeholder: Text('Seleziona la Variabile ${index + 1}'),
              items: widget.availableVariables
                  .map(
                    (v) => ComboBoxItem(
                  value: v.name,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.accentColor
                              .defaultBrushFor(theme.brightness)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          v.dataType.toUpperCase(),
                          style: theme.typography.caption?.copyWith(
                            color: theme.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(v.name),
                    ],
                  ),
                ),
              )
                  .toList(),
              onChanged: (value) {
                setState(() => _arguments[index] = value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: FaIcon(FontAwesomeIcons.trash, size: 16, color: errorColor),
            onPressed: () => _removeArgument(index),
            style: ButtonStyle(
              backgroundColor: ButtonState.resolveWith((states) {
                if (states.contains(ButtonStates.hovered)) {
                  return (theme.brightness == Brightness.light
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFEF4444))
                      .withValues(alpha: 0.1);
                }
                return Colors.transparent;
              }),
            ),
          ),
        ],
      ),
    );
  }
}

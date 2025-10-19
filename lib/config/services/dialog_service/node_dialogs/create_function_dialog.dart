import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Dialog per creare una nuova funzione con la sua firma completa.
/// La firma include: nome, tipo di ritorno e parametri.
/// Dopo la creazione, solo il nome sarà modificabile.
Future<FunctionSignatureData?> showCreateFunctionDialog(
  BuildContext context, {
  required Set<String> existingFileNames,
}) {
  return showDialog<FunctionSignatureData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateFunctionDialog(existingFileNames: existingFileNames),
  );
}

class FunctionSignatureData {
  final String name;
  final String returnType;
  final List<FunctionParam> parameters;

  const FunctionSignatureData({
    required this.name,
    required this.returnType,
    required this.parameters,
  });
}

class _CreateFunctionDialog extends StatefulWidget {
  final Set<String> existingFileNames;
  const _CreateFunctionDialog({required this.existingFileNames});

  @override
  State<_CreateFunctionDialog> createState() => _CreateFunctionDialogState();
}

class _CreateFunctionDialogState extends State<_CreateFunctionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _returnType = 'void';
  final List<_ParamEntry> _parameters = [];

  @override
  void dispose() {
    _nameController.dispose();
    for (var param in _parameters) {
      param.dispose();
    }
    super.dispose();
  }

  List<String> get _availableDataTypes => [
        'void',
        'string',
        'int',
        'double',
        'bool',
      ];

  void _addParameter() {
    setState(() => _parameters.add(_ParamEntry()));
  }

  void _removeParameter(int index) {
    setState(() {
      _parameters[index].dispose();
      _parameters.removeAt(index);
    });
  }

  void _onConfirm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final parameters = _parameters
        .map((p) => FunctionParam(
              name: p.nameController.text.trim(),
              type: p.type,
            ))
        .toList();

    Navigator.of(context).pop(FunctionSignatureData(
      name: name,
      returnType: _returnType,
      parameters: parameters,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
      title: _buildHeader(context),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionLabel(context, 'Nome Sottoprogramma', isRequired: true),
              const SizedBox(height: 8),
              Text(
                'Questo sarà l\'identificativo della funzione. Potrà essere modificato in seguito.',
                style: theme.typography.caption,
              ),
              const SizedBox(height: 12),
              TextFormBox(
                controller: _nameController,
                placeholder: 'Es. CalcolaArea, ConvertTemperatura...',
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (text) {
                  final name = text?.trim() ?? '';
                  if (name.isEmpty) {
                    return 'Il nome non può essere vuoto.';
                  }
                  if (widget.existingFileNames.contains(name.toLowerCase())) {
                    return 'Un file con questo nome esiste già.';
                  }
                  if (name.toLowerCase() == 'main') {
                    return 'Il nome "main" è riservato.';
                  }
                  // REQUISITO: Aggiunto controllo per i numeri
                  if (RegExp(r'[0-9]').hasMatch(name)) {
                    return 'Il nome non può contenere numeri.';
                  }
                  if (RegExp(r'[^a-zA-Z]').hasMatch(name)) {
                    return 'Sono ammesse solo lettere.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              _buildSectionLabel(context, 'Tipo di Ritorno', isRequired: true),
              const SizedBox(height: 8),
              Text(
                'Il tipo di dato restituito dalla funzione. NON potrà essere modificato dopo la creazione.',
                style: theme.typography.caption,
              ),
              const SizedBox(height: 12),
              ComboBox<String>(
                isExpanded: true,
                value: _returnType,
                items: _availableDataTypes
                    .map((type) => ComboBoxItem(
                          value: type,
                          child: Text(type.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _returnType = val ?? 'void'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildSectionLabel(context, 'Parametri'),
                  ),
                  Button(
                    onPressed: _addParameter,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        FaIcon(FontAwesomeIcons.plus, size: 14),
                        SizedBox(width: 8),
                        Text('Aggiungi Parametro'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Definisci i parametri che la funzione riceverà. La lista NON potrà essere modificata dopo la creazione.',
                style: theme.typography.caption,
              ),
              const SizedBox(height: 16),
              if (_parameters.isEmpty)
                _buildEmptyParametersState(context)
              else
                ..._parameters.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildParameterItem(context, entry.key, entry.value),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        Row(
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
              onPressed: _onConfirm,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              child: const Text('Crea Funzione'),
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
            color: theme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(
            FontAwesomeIcons.fileCode,
            size: 20,
            color: theme.accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nuova Funzione', style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                'Definisci la firma completa della funzione (nome, tipo di ritorno e parametri).',
                style: theme.typography.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, {bool isRequired = false}) {
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

  Widget _buildErrorMessage(BuildContext context, String message, Color errorColor) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.circleExclamation, size: 14, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.typography.caption?.copyWith(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyParametersState(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: theme.resources.layerFillColorAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(FontAwesomeIcons.listUl, size: 24, color: theme.inactiveBackgroundColor),
            const SizedBox(height: 12),
            Text(
              'Nessun parametro definito',
              style: theme.typography.body?.copyWith(color: theme.inactiveColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterItem(BuildContext context, int index, _ParamEntry param) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Parametro ${index + 1}',
                style: theme.typography.bodyStrong?.copyWith(color: theme.accentColor),
              ),
              const Spacer(),
              IconButton(
                icon: FaIcon(FontAwesomeIcons.trash, size: 16, color: Colors.red),
                onPressed: () => _removeParameter(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Nome',
                  child: TextFormBox(
                    controller: param.nameController,
                    placeholder: 'Es. valore, temperatura...',
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (text) {
                      final name = text?.trim() ?? '';
                      if (name.isEmpty) {
                        return 'Obbligatorio.';
                      }
                      // REQUISITI di validazione per i parametri
                      if (RegExp(r'^[0-9]').hasMatch(name)) {
                        return 'Non può iniziare con un numero.';
                      }
                      if (RegExp(r'^[0-9]+$').hasMatch(name)) {
                        return 'Non può essere solo numerico.';
                      }
                      if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) {
                        return 'Formato non valido.';
                      }
                      // Controlla duplicati
                      final otherParamNames = _parameters
                          .where((p) => p != param)
                          .map((p) => p.nameController.text.trim().toLowerCase())
                          .toSet();
                      if (otherParamNames.contains(name.toLowerCase())) {
                        return 'Nome duplicato.';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: InfoLabel(
                  label: 'Tipo',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: param.type,
                    items: _availableDataTypes
                        .where((t) => t != 'void')
                        .map((type) => ComboBoxItem(
                              value: type,
                              child: Text(type.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => param.type = val ?? 'string'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParamEntry {
  final TextEditingController nameController = TextEditingController();
  String type = 'string';

  void dispose() {
    nameController.dispose();
  }
}

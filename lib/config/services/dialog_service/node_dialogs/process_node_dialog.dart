// dart
import 'dart:convert';
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
  MyFile? _selectedFile;
  FlowchartSignature? _selectedSignature;
  String? _resultVariableName;
  final List<String?> _argumentVariables = [];
  bool _attemptedSubmit = false;

  @override
  void initState() {
    super.initState();
  }

  // Estrae la firma dalla funzione selezionata
  Future<void> _loadSignature(MyFile file) async {
    try {
      final content = jsonDecode(file.content);
      final signature = content['signature'];

      if (signature != null) {
        final params = (signature['parameters'] as List?)
            ?.map((p) => FunctionParam.fromJson(p as Map<String, dynamic>))
            .toList() ?? [];

        setState(() {
          _selectedSignature = FlowchartSignature(
            parameters: params,
            returnType: signature['returnType'] ?? 'void',
          );
          _argumentVariables.clear();
          _argumentVariables.addAll(List.filled(params.length, null));
          _resultVariableName = null;
        });
      } else {
        // Funzione legacy senza firma
        setState(() {
          _selectedSignature = const FlowchartSignature();
          _argumentVariables.clear();
          _resultVariableName = null;
        });
      }
    } catch (e) {
      debugPrint('Errore nel parsing della firma: $e');
      setState(() {
        _selectedSignature = const FlowchartSignature();
        _argumentVariables.clear();
        _resultVariableName = null;
      });
    }
  }

  void _onFileSelected(MyFile? file) {
    if (file == null) return;
    setState(() => _selectedFile = file);
    _loadSignature(file);
  }

  // Filtra variabili per tipo compatibile
  List<VariableDeclaration> _getVariablesOfType(String targetType) {
    final filtered = widget.availableVariables
        .where((v) => _isTypeCompatible(v.dataType, targetType))
        .toList();

    debugPrint('=== FILTRO VARIABILI ===');
    debugPrint('Target type: $targetType');
    debugPrint('Variabili disponibili totali: ${widget.availableVariables.length}');
    for (var v in widget.availableVariables) {
      debugPrint('  - ${v.name} (${v.dataType}) - scope: ${v.scope}');
    }
    debugPrint('Variabili filtrate: ${filtered.length}');
    for (var v in filtered) {
      debugPrint('  - ${v.name} (${v.dataType})');
    }

    return filtered;
  }

  bool _isTypeCompatible(String varType, String targetType) {
    final vt = varType.trim().toLowerCase();
    final tt = targetType.trim().toLowerCase();
    if (vt == tt) return true;
    // Conversione implicita consentita: int -> double
    if (tt == 'double' && vt == 'int') return true;
    return false;
  }

  String _autoLabel() {
    if (_selectedFile == null) return "chiama ''";
    final name = _selectedFile!.name.replaceAll("'", r"\'");
    return "chiama '$name'";
  }

  void _onConfirm() {
    setState(() => _attemptedSubmit = true);

    if (_selectedFile == null) return;

    // Valida che tutti i parametri richiesti siano assegnati
    if (_selectedSignature != null) {
      for (int i = 0; i < _selectedSignature!.parameters.length; i++) {
        if (_argumentVariables[i] == null || _argumentVariables[i]!.isEmpty) {
          return; // Mostra errore
        }
      }

      // Valida che se c'è un return type != void, sia selezionata una variabile risultato
      if (_selectedSignature!.returnType != 'void' &&
          (_resultVariableName == null || _resultVariableName!.isEmpty)) {
        return; // Mostra errore
      }
    }

    Navigator.of(context).pop({
      'text': _autoLabel(),
      'flowchartToCall': _selectedFile!.fileId,
      'arguments': _argumentVariables.where((v) => v != null).toList(),
      'resultTarget': _resultVariableName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final errorColor = Colors.red.defaultBrushFor(theme.brightness);

    // Verifica se ci sono funzioni disponibili (escludendo main)
    final availableFunctions = widget.files.where((f) => f.name.toLowerCase() != 'main').toList();
    final hasFunctions = availableFunctions.isNotEmpty;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 750, maxHeight: 700),
      title: _buildHeader(context),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(context, 'Selezione Funzione', isRequired: true),
            const SizedBox(height: 8),

            if (!hasFunctions) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.resources.layerFillColorAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.resources.cardStrokeColorDefault),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.circleInfo,
                      size: 20,
                      color: theme.accentColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nessuna funzione disponibile. È necessario crearne una per procedere.',
                        style: theme.typography.body,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ComboBox<MyFile>(
                isExpanded: true,
                value: _selectedFile,
                items: availableFunctions
                    .map((f) => ComboBoxItem(value: f, child: Text(f.name)))
                    .toList(),
                onChanged: _onFileSelected,
                placeholder: const Text('Seleziona una funzione'),
              ),
              if (_attemptedSubmit && _selectedFile == null)
                _buildErrorMessage(context, 'Devi selezionare una funzione da chiamare', errorColor),
            ],

            // Sezione Valore di Ritorno
            if (_selectedSignature != null && _selectedSignature!.returnType != 'void') ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              _buildSectionLabel(context, 'Gestione Valore di Ritorno', isRequired: true),
              const SizedBox(height: 8),
              Text(
                'La funzione restituisce un valore di tipo: ${_selectedSignature!.returnType.toUpperCase()}',
                style: theme.typography.caption?.copyWith(
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              InfoLabel(
                label: 'Assegna risultato a variabile',
                child: ComboBox<String>(
                  isExpanded: true,
                  value: _resultVariableName,
                  items: _getVariablesOfType(_selectedSignature!.returnType)
                      .map((v) => ComboBoxItem(
                            value: v.name,
                            child: _buildVariableItem(context, v),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _resultVariableName = val),
                  placeholder: const Text('Seleziona una variabile'),
                ),
              ),
              if (_attemptedSubmit && (_resultVariableName == null || _resultVariableName!.isEmpty))
                _buildErrorMessage(
                  context,
                  'Devi selezionare una variabile per il valore di ritorno',
                  errorColor,
                ),
            ],

            // Sezione Parametri
            if (_selectedSignature != null && _selectedSignature!.parameters.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              _buildSectionLabel(context, 'Assegnazione Parametri', isRequired: true),
              const SizedBox(height: 8),
              Text(
                'Seleziona le variabili da passare come argomenti alla funzione.',
                style: theme.typography.caption,
              ),
              const SizedBox(height: 16),
              ..._selectedSignature!.parameters.asMap().entries.map((entry) {
                final index = entry.key;
                final param = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildParameterItem(context, index, param, errorColor),
                );
              }),
            ],

            // Label generato (anteprima)
            if (_selectedFile != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              InfoLabel(
                label: 'Etichetta Generata',
                child: Text(
                  _autoLabel(),
                  style: theme.typography.caption?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.accentColor,
                  ),
                ),
              ),
            ],
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
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              child: const Text('Annulla'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: hasFunctions ? _onConfirm : null,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
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
            color: theme.accentColor.withValues(alpha: 0.1),
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
              Text('Configura Blocco Sottoprogramma', style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(
                'Seleziona una funzione e configura i parametri da passare.',
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

  Widget _buildVariableItem(BuildContext context, VariableDeclaration variable) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            variable.dataType.toUpperCase(),
            style: theme.typography.caption?.copyWith(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(variable.name),
      ],
    );
  }

  Widget _buildParameterItem(
    BuildContext context,
    int index,
    FunctionParam param,
    Color errorColor,
  ) {
    final theme = FluentTheme.of(context);
    final compatibleVars = _getVariablesOfType(param.type);

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
                '${param.name} ',
                style: theme.typography.bodyStrong,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  param.type.toUpperCase(),
                  style: theme.typography.caption?.copyWith(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ComboBox<String>(
            isExpanded: true,
            value: _argumentVariables[index],
            items: compatibleVars
                .map((v) => ComboBoxItem(
                      value: v.name,
                      child: _buildVariableItem(context, v),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _argumentVariables[index] = value);
            },
            placeholder: Text('Seleziona variabile per ${param.name}'),
          ),
          if (_attemptedSubmit &&
              (_argumentVariables[index] == null || _argumentVariables[index]!.isEmpty))
            _buildErrorMessage(
              context,
              'Parametro obbligatorio: devi selezionare una variabile',
              errorColor,
            ),
          if (compatibleVars.isEmpty)
            _buildErrorMessage(
              context,
              'Nessuna variabile compatibile con il tipo ${param.type}',
              errorColor,
            ),
        ],
      ),
    );
  }
}

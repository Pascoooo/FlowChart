import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_repository/file_repository.dart';

// --- UX: Aggiunto `rootNavigator: true` per coerenza con il `pop` interno al dialogo. ---
Future<Map<String, dynamic>?> showProcessNodeDialog(
  BuildContext context, {
  required List<MyFile> files,
}) {
  return showCupertinoDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => ProcessNodeDialog(files: files),
  );
}

class ProcessNodeDialog extends StatefulWidget {
  final List<MyFile> files;
  const ProcessNodeDialog({super.key, required this.files});

  @override
  State<ProcessNodeDialog> createState() => _ProcessNodeDialogState();
}

class _ProcessNodeDialogState extends State<ProcessNodeDialog> {
  static const List<String> _allowedTypes = [
    'void',
    'int',
    'float',
    'double',
    'bool',
    'char',
    'string'
  ];

  MyFile? _selectedFile;
  String _returnType = 'void';
  final List<_ParamRowData> _params = [];
  bool _attemptedSubmit = false;

  @override
  void dispose() {
    for (final p in _params) {
      p.dispose();
    }
    super.dispose();
  }

  // --- REFACTOR: Logica di sanitizzazione del nome resa più robusta e chiara. ---
  String _functionNameFromFile(MyFile file) {
    final raw = file.name;
    final base =
        raw.contains('.') ? raw.substring(0, raw.lastIndexOf('.')) : raw;
    var id = base.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (id.isEmpty) id = 'funzione';
    if (RegExp(r'^[0-9]').hasMatch(id)) id = '_$id';
    return id;
  }

  bool _isValidIdentifier(String v) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(v);

  bool _validateForm() {
    if (_selectedFile == null) return false;

    final names = <String>{};
    bool allParamsValid = true;
    for (final p in _params) {
      final name = p.nameController.text.trim();
      if (name.isEmpty) {
        p.errorText = 'Obbligatorio';
        allParamsValid = false;
      } else if (!_isValidIdentifier(name)) {
        p.errorText = 'Formato non valido';
        allParamsValid = false;
      } else if (names.contains(name)) {
        p.errorText = 'Nome duplicato';
        allParamsValid = false;
      } else {
        p.errorText = null;
      }
      names.add(name);
    }
    return allParamsValid;
  }

  void _addParam() {
    setState(() {
      _params
          .add(_ParamRowData(type: 'int', name: 'param${_params.length + 1}'));
    });
  }

  void _removeParam(int i) {
    setState(() {
      _params[i].dispose();
      _params.removeAt(i);
      // Riesegui la validazione per aggiornare eventuali errori di duplicazione.
      if (_attemptedSubmit) {
        _validateForm();
      }
    });
  }

  void _confirm() {
    setState(() {
      _attemptedSubmit = true;
    });
    if (!_validateForm()) return;

    final file = _selectedFile!;
    final functionName = _functionNameFromFile(file);
    final params = _params
        .map((p) => {
              'name': p.nameController.text.trim(),
              'type': p.typeController.text,
            })
        .toList();

    Navigator.of(context).pop({
      'text': file.name,
      'functionName': functionName,
      'returnType': _returnType,
      'params': params,
      'code': '',
    });
  }

  // --- DESCRIZIONE DELLA MODIFICA: Nessuna modifica a questo helper, è già ben implementato. ---
  Widget _buildStyledDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? errorText,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // La validazione viene eseguita direttamente qui per aggiornare lo stato del pulsante
    final isFormValid = _validateForm();
    final functionPreview = _selectedFile == null
        ? 'Nessun file selezionato'
        : _functionNameFromFile(_selectedFile!);
    final isFunctionPreviewValid =
        _selectedFile != null && _isValidIdentifier(functionPreview);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        width: 550,
        // --- UI/UX: Aumentato il padding per un aspetto più arioso. ---
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Configura Nodo di Processo',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            if (widget.files.isEmpty)
              const Center(
                  child: Text('Nessun file di codice sorgente disponibile.'))
            else ...[
              _buildStyledDropdown<MyFile>(
                label: 'File Sorgente *',
                value: _selectedFile,
                items: widget.files
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (f) => setState(() => _selectedFile = f),
                errorText: _attemptedSubmit && _selectedFile == null
                    ? 'Campo obbligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Nome Funzione Derivato', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surfaceContainerLowest,
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      isFunctionPreviewValid
                          ? FontAwesomeIcons.checkCircle
                          : FontAwesomeIcons.circleXmark,
                      // --- THEME: Rimosso colore hardcoded, ora usa i colori del tema. ---
                      color: isFunctionPreviewValid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        functionPreview,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: _selectedFile == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: _selectedFile == null ? theme.hintColor : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildStyledDropdown<String>(
                label: 'Tipo di Ritorno *',
                value: _returnType,
                items: _allowedTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _returnType = val);
                },
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Parametri', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: _addParam,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.plus,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text('Aggiungi',
                            style: TextStyle(color: theme.colorScheme.primary)),
                      ],
                    ),
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  'I parametri qui definiti saranno disponibili nel codice.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ),
              // --- UI/UX: Stato vuoto migliorato con un'icona e testo più centrato. ---
              if (_params.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                    color: theme.colorScheme.surface,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(FontAwesomeIcons.folderOpen,
                          color: theme.hintColor, size: 24),
                      const SizedBox(height: 12),
                      Text('Nessun parametro definito',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                )
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    children: _params.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final p = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildStyledDropdown<String>(
                                label: 'Tipo',
                                value: p.typeController.text,
                                items: _allowedTypes
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => p.typeController.text = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: p.nameController,
                                style: theme.textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  labelText: 'Nome',
                                  errorText:
                                      _attemptedSubmit ? p.errorText : null,
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                      color:
                                          theme.dividerColor.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                onChanged: (_) => setState(() {
                                  if (_attemptedSubmit) _validateForm();
                                }),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: CupertinoButton(
                                padding: const EdgeInsets.all(10),
                                child: FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                onPressed: () => _removeParam(idx),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
            const SizedBox(height: 32),
            // --- UI/UX: Sostituzione dei pulsanti Material con azioni in stile Cupertino. ---
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text('Annulla',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton.filled(
                    onPressed: _confirm,
                    child: const Text('Conferma'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParamRowData {
  final TextEditingController typeController;
  final TextEditingController nameController;
  String? errorText;

  _ParamRowData({String type = '', String name = ''})
      : typeController = TextEditingController(text: type),
        nameController = TextEditingController(text: name);

  void dispose() {
    typeController.dispose();
    nameController.dispose();
  }
}

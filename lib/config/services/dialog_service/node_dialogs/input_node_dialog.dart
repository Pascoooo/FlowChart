import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

// --- MODIFICA: La funzione ora accetta la lista dei nomi esistenti ---
Future<Map<String, dynamic>?> showInputNodeDialog(
    BuildContext context, {
      // Usiamo un Set per ricerche più veloci
      required Set<String> existingVariableNames,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _InputNodeDialog(existingVariableNames: existingVariableNames),
  );
}

class _InputNodeDialog extends StatefulWidget {
  // --- MODIFICA: Il dialogo ora conosce i nomi delle variabili già presenti nel flowchart ---
  final Set<String> existingVariableNames;
  const _InputNodeDialog({required this.existingVariableNames});

  @override
  State<_InputNodeDialog> createState() => _InputNodeDialogState();
}

class _InputNodeDialogState extends State<_InputNodeDialog> {
  final TextEditingController _labelController = TextEditingController();
  final List<_VarRowData> _vars = [];
  bool _attemptedSubmit = false;

  static const _cTypes = <String>[
    'int', 'float', 'double', 'bool', 'char', 'string'
  ];

  @override
  void initState() {
    super.initState();
    // Inizia con una variabile di default per comodità dell'utente
    _addVar();
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final v in _vars) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVar() =>
      setState(() => _vars.add(_VarRowData(type: 'int', hasInit: true)));

  void _removeVar(int i) {
    _vars[i].dispose();
    setState(() => _vars.removeAt(i));
    if (_attemptedSubmit) _validateForm();
  }

  bool _validateValue(String type, String value) {
    if (value.isEmpty) return false;
    switch (type) {
      case 'int': return int.tryParse(value) != null;
      case 'float': case 'double': return double.tryParse(value) != null;
      case 'bool': return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1;
      case 'string': return true;
      default: return false;
    }
  }

  bool _validateForm() {
    if (_vars.isEmpty) return false;
    final names = <String, List<int>>{};
    bool isFormValid = true;

    for (var i = 0; i < _vars.length; i++) {
      final v = _vars[i];
      final name = v.name.text.trim();
      final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

      if (name.isEmpty) {
        v.nameError = 'Obbligatorio';
      } else if (!idRe.hasMatch(name)) {
        v.nameError = 'Formato non valido';
        // --- MODIFICA: Aggiunto controllo sui nomi già esistenti nel flowchart ---
      } else if (widget.existingVariableNames.contains(name)) {
        v.nameError = 'Nome già in uso';
      } else {
        v.nameError = null;
        names.putIfAbsent(name, () => []).add(i);
      }

      if (v.hasInit) {
        final val = v.init.text.trim();
        if (val.isEmpty) {
          v.initError = 'Obbligatorio';
        } else if (!_validateValue(v.type, val)) {
          v.initError = 'Valore non valido per il tipo "${v.type}"';
        } else {
          v.initError = null;
        }
      } else {
        v.initError = null;
      }

      if (v.nameError != null || v.initError != null) {
        isFormValid = false;
      }
    }

    // Questa parte, già presente, gestisce i duplicati all'interno del dialogo stesso
    names.forEach((name, indices) {
      if (indices.length > 1) {
        isFormValid = false;
        for (var index in indices) {
          _vars[index].nameError = 'Nome già usato';
        }
      }
    });
    return isFormValid;
  }

  dynamic _parseValue(String type, String value) {
    if (value.isEmpty) return null;
    switch (type) {
      case 'int': return int.tryParse(value) ?? 0;
      case 'float': case 'double': return double.tryParse(value) ?? 0.0;
      case 'bool': return ['true', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1 ? value : null;
      default: return value;
    }
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    // La validazione ora controlla entrambi i tipi di duplicati
    if (!_validateForm()) return;

    Navigator.of(context).pop({
      'text': _labelController.text.trim().isEmpty ? 'Input' : _labelController.text.trim(),
      'declarations': _vars.map((v) {
        final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;

        return {
          'name': v.name.text.trim(),
          'dataType': v.type,
          'defaultValue': defaultValue,
        };
      }).toList(),
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(FontAwesomeIcons.keyboard, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text('Configura Nodo Input', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Definisci le variabili che il programma richiederà in input.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Etichetta Nodo (opzionale)',
                hintText: 'Es. Inserimento Dati Utente',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Variabili da Dichiarare', style: theme.textTheme.titleLarge),
                const Spacer(),
                CupertinoButton.filled(
                  onPressed: _addVar,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            const SizedBox(height: 16),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _vars.isEmpty
                    ? Center(
                    child: Text('Aggiungi almeno una variabile.',
                        style: TextStyle(color: theme.hintColor)))
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _vars.length,
                  itemBuilder: (_, i) => _buildVarRow(i),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Annulla', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                  onPressed: _confirm,
                  child: const Text('Conferma'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVarRow(int index) {
    final v = _vars[index];
    final theme = Theme.of(context);

    if (_attemptedSubmit) _validateForm();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: v.name,
                  decoration: InputDecoration(
                    labelText: 'Nome Variabile *',
                    errorText: _attemptedSubmit ? v.nameError : null,
                  ),
                  onChanged: (_) {
                    if (_attemptedSubmit) setState(() => _validateForm());
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: v.type,
                  items: _cTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() {
                    v.type = val!;
                    v.init.clear();
                  }),
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: CupertinoButton(
                    padding: const EdgeInsets.all(10),
                    minSize: 0,
                    onPressed: () => _removeVar(index),
                    child: FaIcon(FontAwesomeIcons.trash, size: 18, color: theme.colorScheme.error)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Inizializza con un valore'),
            value: v.hasInit,
            onChanged: (val) => setState(() {
              v.hasInit = val;
              if (!val) v.init.clear();
            }),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (v.hasInit)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: TextField(
                controller: v.init,
                decoration: InputDecoration(
                  labelText: 'Valore Iniziale *',
                  errorText: _attemptedSubmit ? v.initError : null,
                ),
                onChanged: (_) {
                  if (_attemptedSubmit) setState(() => _validateForm());
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VarRowData {
  final TextEditingController name = TextEditingController();
  final TextEditingController init = TextEditingController();
  String type;
  bool hasInit;
  String? nameError;
  String? initError;

  _VarRowData({required this.type, this.hasInit = false});

  void dispose() {
    name.dispose();
    init.dispose();
  }
}
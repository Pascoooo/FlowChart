import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

Future<Map<String, dynamic>?> showInputNodeDialog(
    BuildContext context, {
      required Set<String> existingVariableNames,
      required List<VariableDeclaration> existingDeclarations,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InputNodeDialog(
      existingDeclarations: existingDeclarations,
    ),
  );
}

class _InputNodeDialog extends StatefulWidget {
  final List<VariableDeclaration> existingDeclarations;

  const _InputNodeDialog({
    required this.existingDeclarations,
  });

  @override
  State<_InputNodeDialog> createState() => _InputNodeDialogState();
}

class _InputNodeDialogState extends State<_InputNodeDialog> {
  final TextEditingController _labelController = TextEditingController();
  final List<_VarRowData> _vars = [];
  final List<_AssignmentRowData> _assignments = [];
  bool _attemptedSubmit = false;
  int _currentTab = 0;

  static const _cTypes = <String>['int', 'float', 'double', 'bool', 'char', 'string'];

  @override
  void initState() {
    super.initState();
    _addVar();
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final v in _vars) {
      v.dispose();
    }
    for (final a in _assignments) {
      a.dispose();
    }
    super.dispose();
  }

  void _addVar() => setState(() => _vars.add(_VarRowData(type: 'int', hasInit: false)));

  void _removeVar(int i) {
    setState(() {
      final removedName = _vars[i].name.text.trim();
      _vars[i].dispose();
      _vars.removeAt(i);
      _assignments.removeWhere((a) => a.target == removedName);
    });
    if (_attemptedSubmit) _validateForm();
  }

  void _addAssignment() => setState(() => _assignments.add(_AssignmentRowData()));

  void _removeAssignment(int i) {
    setState(() {
      _assignments[i].dispose();
      _assignments.removeAt(i);
    });
    if (_attemptedSubmit) _validateForm();
  }

  bool _validateValue(String type, String value) {
    if (value.isEmpty) return false;
    switch (type) {
      case 'int': return int.tryParse(value) != null;
      case 'float':
      case 'double': return double.tryParse(value) != null;
      case 'bool': return ['true', 'false', '0', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1;
      case 'string': return true;
      default: return false;
    }
  }

  bool _isTypeCompatible(String targetType, String sourceType) {
    if (targetType == sourceType) return true;
    if ((targetType == 'float' || targetType == 'double') && sourceType == 'int') return true;
    return false;
  }

  bool _validateAssignments(List<VariableDeclaration> allAvailableVars) {
    bool ok = true;
    final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    for (final a in _assignments) {
      a.targetError = null;
      a.valueError = null;
      if (a.target == null || a.target!.trim().isEmpty) {
        a.targetError = 'Obbligatorio';
        ok = false;
      } else if (!allAvailableVars.any((v) => v.name == a.target)) {
        a.targetError = 'Variabile inesistente';
        ok = false;
      }

      final token = a.value.text.trim();
      if (token.isEmpty) {
        a.valueError = 'Obbligatorio';
        ok = false;
      } else {
        final targetVar = allAvailableVars.where((v) => v.name == a.target);
        if (targetVar.isNotEmpty) {
          final targetType = targetVar.first.dataType;
          if (idRe.hasMatch(token)) {
            final sourceVar = allAvailableVars.where((v) => v.name == token);
            if (sourceVar.isEmpty) {
              a.valueError = 'Variabile inesistente';
              ok = false;
            } else if (!_isTypeCompatible(targetType, sourceVar.first.dataType)) {
              a.valueError = 'Tipo incompatibile';
              ok = false;
            }
          } else {
            if (!_validateValue(targetType, token)) {
              a.valueError = 'Valore non valido';
              ok = false;
            }
          }
        }
      }
    }
    return ok;
  }

  bool _validateForm() {
    final names = <String, List<int>>{};
    bool isFormValid = true;

    // MODIFICA: Creiamo le istanze di VariableDeclaration complete di defaultValue.
    final newlyDeclaredVars = _vars
        .where((v) => v.name.text.trim().isNotEmpty)
        .map((v) {
      final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
      return VariableDeclaration(
        name: v.name.text.trim(),
        dataType: v.type,
        defaultValue: defaultValue,
      );
    })
        .toList();

    // MODIFICA: Esplicitiamo il tipo della lista per evitare errori.
    final List<VariableDeclaration> allAvailableVars = [...widget.existingDeclarations, ...newlyDeclaredVars];

    for (var i = 0; i < _vars.length; i++) {
      final v = _vars[i];
      final name = v.name.text.trim();
      final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

      if (name.isEmpty) {
        v.nameError = 'Obbligatorio';
      } else if (!idRe.hasMatch(name)) {
        v.nameError = 'Formato non valido';
      } else if (widget.existingDeclarations.any((d) => d.name == name)) {
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
          v.initError = 'Valore non valido';
        } else {
          v.initError = null;
        }
      } else {
        v.initError = null;
      }
      if (v.nameError != null || v.initError != null) isFormValid = false;
    }

    names.forEach((_, indices) {
      if (indices.length > 1) {
        isFormValid = false;
        for (var index in indices) {
          _vars[index].nameError = 'Nome duplicato';
        }
      }
    });

    if (!_validateAssignments(allAvailableVars)) isFormValid = false;
    setState(() {});
    return isFormValid;
  }

  dynamic _parseValue(String type, String value) {
    if (value.isEmpty) return null;
    switch (type) {
      case 'int': return int.tryParse(value) ?? 0;
      case 'float':
      case 'double': return double.tryParse(value) ?? 0.0;
      case 'bool': return ['true', '1'].contains(value.toLowerCase());
      case 'char': return value.length == 1 ? value : null;
      default: return value;
    }
  }

  void _confirm() {
    setState(() => _attemptedSubmit = true);
    if (!_validateForm()) return;
    Navigator.of(context).pop({
      'text': _labelController.text.trim().isEmpty ? 'Input' : _labelController.text.trim(),
      'declarations': _vars.map((v) {
        final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
        return {'name': v.name.text.trim(), 'dataType': v.type, 'defaultValue': defaultValue};
      }).toList(),
      'assignments': _assignments.map((a) {
        final token = a.value.text.trim();
        final idRe = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

        // MODIFICA: Aggiunto defaultValue anche qui per creare una lista completa.
        final allVars = [
          ...widget.existingDeclarations,
          ..._vars.map((v) {
            final dynamic defaultValue = v.hasInit ? _parseValue(v.type, v.init.text.trim()) : null;
            return VariableDeclaration(
              name: v.name.text.trim(),
              dataType: v.type,
              defaultValue: defaultValue,
            );
          })
        ];

        if (idRe.hasMatch(token) && allVars.any((v) => v.name == token)) {
          return {'target': a.target, 'type': 'variable', 'source': token};
        }

        final targetType = allVars.firstWhere((v) => v.name == a.target!).dataType;
        return {'target': a.target, 'type': 'literal', 'value': _parseValue(targetType, token)};
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
      content: SizedBox(
        height: 680,
        child: Column(
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            InfoLabel(
              label: 'Etichetta Nodo (opzionale)',
              child: TextBox(
                controller: _labelController,
                placeholder: 'Es. Inserimento Dati Utente',
                onChanged: (_) { if (_attemptedSubmit) _validateForm(); },
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabView(
                currentIndex: _currentTab,
                onChanged: (i) => setState(() => _currentTab = i),
                tabs: [
                  Tab(
                    text: const Text('Dichiara'),
                    icon: const Icon(FluentIcons.variable),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildDeclarationsSection(theme),
                    ),
                  ),
                  Tab(
                    text: const Text('Assegna'),
                    icon: const Icon(FluentIcons.dependency_add),
                    body: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildAssignmentsSection(theme),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclarationsSection(FluentThemeData theme) {
    return Column(
      children: [
        _buildVarHeader(theme),
        const SizedBox(height: 16),
        Expanded(
          child: _vars.isEmpty
              ? _buildEmptyState(theme)
              : ListView.separated(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: _vars.length,
            itemBuilder: (_, i) => _buildVarRow(i, theme),
            separatorBuilder: (_, __) => const SizedBox(height: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentsSection(FluentThemeData theme) {
    final allAvailableVarNames = {
      ...widget.existingDeclarations.map((d) => d.name),
      ..._vars.map((v) => v.name.text.trim()).where((n) => n.isNotEmpty),
    }.toList();

    return Column(
      children: [
        _buildAssignmentsHeader(theme),
        const SizedBox(height: 12),
        Expanded(
          child: allAvailableVarNames.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Dichiara una variabile nel tab "Dichiara" per poter effettuare assegnazioni.',
                style: theme.typography.caption,
                textAlign: TextAlign.center,
              ),
            ),
          )
              : _assignments.isEmpty
              ? SingleChildScrollView(child: _buildEmptyAssignments(theme))
              : ListView.builder(
            itemCount: _assignments.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAssignmentRow(i, theme, allAvailableVarNames),
            ),
          ),
        ),
      ],
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
              Text('Configura Nodo Input', style: theme.typography.title),
              Text('Definisci nuove variabili e assegna loro un valore.', style: theme.typography.body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVarHeader(FluentThemeData theme) {
    return Row(
      children: [
        Text('Variabili da Dichiarare', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: _addVar,
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.plus, size: 14),
              SizedBox(width: 8),
              Text('Aggiungi Variabile'),
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
          Icon(FontAwesomeIcons.circleInfo, size: 48, color: theme.accentColor),
          const SizedBox(height: 16),
          Text('Nessuna variabile definita', style: theme.typography.bodyLarge),
          const SizedBox(height: 4),
          Text('Aggiungi la prima variabile per iniziare.', style: theme.typography.caption),
        ],
      ),
    );
  }

  Widget _buildVarRow(int index, FluentThemeData theme) {
    final v = _vars[index];
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.grey[20] : theme.cardColor.withOpacity(0.5),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: InfoLabel(
                  label: 'Nome Variabile *',
                  child: TextBox(controller: v.name, onChanged: (_) { if (_attemptedSubmit) _validateForm(); }),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: InfoLabel(
                  label: 'Tipo *',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: v.type,
                    items: _cTypes.map((t) => ComboBoxItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        v.type = val;
                        v.init.clear();
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: AnimatedOpacity(
                  opacity: v.hasInit ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: InfoLabel(
                    label: 'Valore Iniziale',
                    child: TextBox(
                      controller: v.init,
                      enabled: v.hasInit,
                      onChanged: (_) { if (_attemptedSubmit) _validateForm(); },
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
                    checked: v.hasInit,
                    onChanged: (val) => setState(() {
                      if (val != null) {
                        v.hasInit = val;
                        if (!val) v.init.clear();
                        if (_attemptedSubmit) _validateForm();
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeVar(index),
                style: ButtonStyle(
                  foregroundColor: ButtonState.resolveWith((states) {
                    final color = Colors.red.defaultBrushFor(theme.brightness);
                    return states.isHovering ? Colors.white : color;
                  }),
                  backgroundColor: ButtonState.resolveWith((states) => states.isHovering ? Colors.red : Colors.transparent),
                ),
                icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
              ),
            ],
          ),
          if (_attemptedSubmit && (v.nameError != null || v.initError != null)) _buildErrorMessages(v),
        ],
      ),
    );
  }

  Widget _buildErrorMessages(_VarRowData v) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 2.0, right: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: _ErrorMessage(v.nameError ?? '')),
          const SizedBox(width: 16),
          const Spacer(flex: 2),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: _ErrorMessage(v.initError ?? '')),
          const SizedBox(width: 16),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

  Widget _buildAssignmentsHeader(FluentThemeData theme) {
    final allAvailableVars = {
      ...widget.existingDeclarations.map((d) => d.name),
      ..._vars.map((v) => v.name.text.trim()).where((n) => n.isNotEmpty)
    };
    return Row(
      children: [
        Text('Assegnazioni (opzionale)', style: theme.typography.subtitle),
        const Spacer(),
        FilledButton(
          onPressed: allAvailableVars.isEmpty ? null : _addAssignment,
          child: const Row(
            children: [
              Icon(FontAwesomeIcons.plus, size: 14),
              SizedBox(width: 6),
              Text('Aggiungi Assegnazione'),
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
        child: Text('Nessuna assegnazione aggiunta.', style: theme.typography.caption),
      ),
    );
  }

  Widget _buildAssignmentRow(int index, FluentThemeData theme, List<String> availableVarNames) {
    final a = _assignments[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light ? Colors.grey[10] : theme.cardColor.withOpacity(0.4),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InfoLabel(
                  label: 'Variabile di destinazione*',
                  child: ComboBox<String>(
                    isExpanded: true,
                    value: a.target != null && availableVarNames.contains(a.target) ? a.target : null,
                    items: availableVarNames.map((n) => ComboBoxItem(value: n, child: Text(n))).toList(),
                    onChanged: (val) {
                      setState(() {
                        a.target = val;
                        if (_attemptedSubmit) _validateForm();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: InfoLabel(
                  label: 'Valore o variabile sorgente*',
                  child: TextBox(
                    controller: a.value,
                    placeholder: 'Es: 10 oppure nome_variabile',
                    onChanged: (_) { if (_attemptedSubmit) _validateForm(); },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _removeAssignment(index),
                icon: const FaIcon(FontAwesomeIcons.trash, size: 14),
                style: ButtonStyle(
                  foregroundColor: ButtonState.resolveWith((states) {
                    final color = Colors.red.defaultBrushFor(theme.brightness);
                    return states.isHovering ? Colors.white : color;
                  }),
                  backgroundColor: ButtonState.resolveWith((states) => states.isHovering ? Colors.red : Colors.transparent),
                ),
              ),
            ],
          ),
          if (_attemptedSubmit && (a.targetError != null || a.valueError != null))
            Padding(
              padding: const EdgeInsets.only(top: 6.0, left: 2, right: 2),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _ErrorMessage(a.targetError ?? '')),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: _ErrorMessage(a.valueError ?? '')),
                  const SizedBox(width: 12),
                  const SizedBox(width: 32),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Button(
          onPressed: () => Navigator.of(context).pop(null),
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
    return Text(
      message,
      style: theme.typography.caption?.copyWith(color: Colors.red.defaultBrushFor(theme.brightness)),
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

class _AssignmentRowData {
  String? target;
  final TextEditingController value = TextEditingController();
  String? targetError;
  String? valueError;
  void dispose() { value.dispose(); }
}
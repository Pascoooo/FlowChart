import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_repository/file_repository.dart';

Future<Map<String, dynamic>?> showProcessNodeDialog(
    BuildContext context, {
      required List<MyFile> files,
    }) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => _ProcessNodeDialog(files: files),
  );
}

class _ProcessNodeDialog extends StatefulWidget {
  final List<MyFile> files;
  const _ProcessNodeDialog({required this.files});

  @override
  State<_ProcessNodeDialog> createState() => _ProcessNodeDialogState();
}

class _ProcessNodeDialogState extends State<_ProcessNodeDialog> {
  final _labelController = TextEditingController();
  final _resultTargetController = TextEditingController();
  final List<TextEditingController> _argumentControllers = [];
  MyFile? _selectedFile;
  bool _attemptedSubmit = false;

  @override
  void dispose() {
    _labelController.dispose();
    _resultTargetController.dispose();
    for (final controller in _argumentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addArgument() => setState(() => _argumentControllers.add(TextEditingController()));

  void _removeArgument(int index) {
    _argumentControllers.removeAt(index).dispose();
    setState(() {});
  }

  void _onConfirm() {
    setState(() => _attemptedSubmit = true);
    if (_selectedFile == null) return;

    final arguments = _argumentControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // **FIX**: Restituisce la mappa con le chiavi corrette per la nuova architettura
    Navigator.of(context).pop({
      'text': _labelController.text.trim().isNotEmpty
          ? _labelController.text.trim()
          : 'Chiama: ${_selectedFile!.name}',
      'flowchartToCall': _selectedFile!.fileId, // <-- CHIAVE CORRETTA CON L'ID
      'arguments': arguments,
      'resultTarget': _resultTargetController.text.trim().isEmpty
          ? null
          : _resultTargetController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                FaIcon(FontAwesomeIcons.gears, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text('Configura Nodo di Processo', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<MyFile>(
              value: _selectedFile,
              items: widget.files
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedFile = val),
              decoration: InputDecoration(
                labelText: 'Flowchart da chiamare *',
                errorText: _attemptedSubmit && _selectedFile == null
                    ? 'Campo obbligatorio'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                    labelText: 'Etichetta Nodo (opzionale)')),
            const SizedBox(height: 16),
            TextField(
                controller: _resultTargetController,
                decoration: const InputDecoration(
                    labelText: 'Variabile per il risultato (opzionale)',
                    hintText: 'Es. mio_risultato')),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Argomenti', style: theme.textTheme.titleMedium),
                const Spacer(),
                CupertinoButton(
                  onPressed: _addArgument,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(FontAwesomeIcons.plus, size: 14),
                      const SizedBox(width: 8),
                      const Text('Aggiungi'),
                    ],
                  ),
                ),
              ],
            ),
            Text('Nomi delle variabili da passare in ordine.', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: _argumentControllers.isEmpty
                    ? Center(child: Text('Nessun argomento specificato.', style: TextStyle(color: theme.hintColor)))
                    : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _argumentControllers.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                            child: TextField(
                                controller: _argumentControllers[index],
                                decoration: InputDecoration(
                                    labelText: 'Argomento ${index + 1}',
                                    hintText: 'Es. variabile_${index + 1}'))),
                        IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
                            onPressed: () => _removeArgument(index)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla')),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                    onPressed: _onConfirm, child: const Text('Conferma')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
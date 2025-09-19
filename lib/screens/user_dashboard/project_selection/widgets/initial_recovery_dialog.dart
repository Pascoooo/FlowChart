import 'package:flutter/material.dart';

class InitialRecoveryDialog extends StatelessWidget {
  final String projectName;
  final VoidCallback onRecoverAll;
  final VoidCallback onDiscardAll;
  final VoidCallback onManualSelect;

  const InitialRecoveryDialog({
    super.key,
    required this.projectName,
    required this.onRecoverAll,
    required this.onDiscardAll,
    required this.onManualSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Recupero Sessione per "$projectName"'),
      content: const Text("Sono state trovate modifiche non salvate in uno o più file. Come vuoi procedere?"),
      actions: [
        TextButton(
          onPressed: onDiscardAll,
          child: const Text("Scarta tutti"),
        ),
        TextButton(
          onPressed: onManualSelect,
          child: const Text("Scegli manualmente"),
        ),
        ElevatedButton(
          onPressed: onRecoverAll,
          child: const Text("Recupera tutti"),
        ),
      ],
    );
  }
}
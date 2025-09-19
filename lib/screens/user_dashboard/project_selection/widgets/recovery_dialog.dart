import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../project_workspace/views/workarea.dart';

class RecoveryDialog extends StatelessWidget {
  final String projectName;
  final String firestoreContent;
  final String rtdbContent;
  final VoidCallback onRecover;
  final VoidCallback onDiscard;

  const RecoveryDialog({
    super.key,
    required this.projectName,
    required this.firestoreContent,
    required this.rtdbContent,
    required this.onRecover,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(child: Text('Recupero Sessione per "$projectName"')),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Abbiamo trovato modifiche non salvate. Scegli quale versione conservare.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- MODIFICA: Passata la nuova etichetta "Prima" ---
                  Expanded(
                    child: _buildVersionColumn(
                      context,
                      title: "Prima",
                      content: firestoreContent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // --- MODIFICA: Passata la nuova etichetta "Dopo" ---
                  Expanded(
                    child: _buildVersionColumn(
                      context,
                      title: "Dopo (modifiche non salvate)",
                      content: rtdbContent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      // --- MODIFICA: Spostati e rinominati i pulsanti qui ---
      actions: <Widget>[
        TextButton(
          onPressed: onDiscard,
          child: const Text("Scarta modifiche"),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onRecover,
          child: const Text("Recupera modifiche"),
        ),
      ],
    );
  }

  // --- MODIFICA: Rimosso il pulsante da questa funzione ausiliaria ---
  Widget _buildVersionColumn(BuildContext context, {
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    final GlobalKey previewKey = GlobalKey();

    return Column(
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        BlocProvider(
          create: (context) => FlowchartBloc()..add(LoadFlowchart(content)),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8)
              ),
              clipBehavior: Clip.hardEdge,
              child: IgnorePointer(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 1200,
                    height: 750,
                    child: WorkArea(
                      repaintKey: previewKey,
                      showGrid: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
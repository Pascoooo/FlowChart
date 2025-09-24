import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:file_repository/file_repository.dart';

// --- REFACTOR: La funzione `showNodeDataDialog` è stata estratta dalla classe del widget. ---
// La logica per *creare* un nodo non dovrebbe risiedere in un widget che ne *mostra i dettagli*.
// Questa funzione dovrebbe trovarsi in una classe di servizio apposita (es. AppDialogs).
Future<Map<String, dynamic>?> showNodeCreationDialog({
  required BuildContext context,
  required FlowNodeKind kind,
  List<MyFile>? files,
  List<Map<String, String>>? variables,
}) {
  // Nota: questa logica dovrebbe richiamare i rispettivi dialoghi di creazione
  // (es. showInputNodeDialog, showProcessNodeDialog, etc.) che abbiamo già refactored.
  // Qui viene lasciata come riferimento strutturale.
  debugPrint("Mostra dialogo di creazione per il tipo: $kind");
  // Esempio: if (kind == FlowNodeKind.input) return showInputNodeDialog(context);
  return Future.value(null);
}

Future<void> showNodeDetailsDialog({
  required BuildContext context,
  required FlowNode node,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => _NodeDetailsDialog(node: node),
  );
}

class _NodeDetailsDialog extends StatelessWidget {
  final FlowNode node;
  const _NodeDetailsDialog({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, IconData icon) = _getTitleAndIcon(node.kind);

    // --- REFACTOR: Sostituito CupertinoAlertDialog con un Dialog personalizzato per un controllo totale su UI/UX. ---
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KeyValueDetail(
                      label: 'Etichetta Nodo',
                      value: node.text,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    ..._buildSpecificDetails(context, theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, IconData) _getTitleAndIcon(FlowNodeKind kind) {
    return switch (kind) {
      FlowNodeKind.input => ('Dettagli Input', FontAwesomeIcons.keyboard),
      FlowNodeKind.output => ('Dettagli Output', FontAwesomeIcons.terminal),
      FlowNodeKind.process => ('Dettagli Processo', FontAwesomeIcons.gear),
      FlowNodeKind.decision =>
      ('Dettagli Condizione', FontAwesomeIcons.codeBranch),
      FlowNodeKind.start => ('Dettagli Inizio', FontAwesomeIcons.play),
      FlowNodeKind.end => ('Dettagli Fine', FontAwesomeIcons.flagCheckered),
    };
  }

  // --- UI/UX: La logica di visualizzazione è stata riorganizzata per usare widget helper più specifici. ---
  List<Widget> _buildSpecificDetails(BuildContext context, ThemeData theme) {
    switch (node.kind) {
      case FlowNodeKind.input:
        final inputNode = node as InputNode;
        return [
          _SectionTitle(title: 'Variabili Dichiarate', theme: theme),
          const SizedBox(height: 8),
          if (inputNode.declarations.isEmpty)
            _EmptyState(message: 'Nessuna variabile dichiarata.', theme: theme)
          else
            _BoxedDetail(
              theme: theme,
              value: '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: inputNode.declarations.map((v) {
                  final hasValue = v.initialValue != null &&
                      v.initialValue.toString().trim().isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                              text: '${v.dataType} ',
                              style:
                              TextStyle(color: theme.colorScheme.primary)),
                          TextSpan(
                              text: v.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          if (hasValue)
                            TextSpan(text: ' = ${v.initialValue}'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ];

      case FlowNodeKind.output:
        final outputNode = node as OutputNode;
        return [
          _KeyValueDetail(
              label: 'Messaggio Template',
              value: outputNode.template,
              theme: theme),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Variabili Utilizzate', theme: theme),
          const SizedBox(height: 8),
          if (outputNode.variables.isEmpty)
            _EmptyState(
                message: 'Nessuna variabile specificata.', theme: theme)
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: outputNode.variables
                  .map((v) => _VariableChip(variable: v, theme: theme))
                  .toList(),
            ),
        ];

      case FlowNodeKind.process:
        final processNode = node as ProcessNode;
        final signature = (processNode.functionName != null)
            ? '${processNode.returnType ?? 'void'} ${processNode.functionName!}(${processNode.params.map((p) => '${p.type} ${p.name}').join(', ')})'
            : (processNode.code.isNotEmpty ? processNode.code : '-');
        return [
          _KeyValueDetail(label: 'File Sorgente', value: processNode.text, theme: theme),
          const SizedBox(height: 12),
          _BoxedDetail(
              label: 'Funzione Eseguita',
              value: signature,
              theme: theme,
              isCode: true),
        ];

      case FlowNodeKind.decision:
        final decisionNode = node as DecisionNode;
        return [
          _BoxedDetail(
              label: 'Condizione',
              value: decisionNode.condition,
              theme: theme,
              isCode: true),
        ];

      default:
        return [
          _EmptyState(
              message: 'Nessun dato aggiuntivo disponibile.', theme: theme)
        ];
    }
  }
}

// --- REFACTOR: Creati widget helper specifici e riutilizzabili per ogni tipo di dettaglio. ---

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionTitle({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
    );
  }
}

class _KeyValueDetail extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  const _KeyValueDetail(
      {required this.label, required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: label, theme: theme),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '-' : value,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _BoxedDetail extends StatelessWidget {
  final String? label;
  final String value;
  final Widget? child;
  final bool isCode;
  final ThemeData theme;

  const _BoxedDetail({
    required this.value,
    this.label,
    this.child,
    this.isCode = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          _SectionTitle(title: label!, theme: theme),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: child ??
              Text(
                value.isEmpty ? '-' : value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: isCode ? 'monospace' : null,
                ),
              ),
        ),
      ],
    );
  }
}

class _VariableChip extends StatelessWidget {
  final String variable;
  final ThemeData theme;
  const _VariableChip({required this.variable, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        variable,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// --- REFACTOR: Lo stato vuoto ora è un widget riutilizzabile e basato sul tema. ---
class _EmptyState extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _EmptyState({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.hintColor,
      ),
    );
  }
}
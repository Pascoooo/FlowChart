// Tuo file info_node_dialog.dart

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ... (il resto degli import)

/// 📋 Node Details Dialog - Professional Information Display
Future<void> showNodeDetailsDialog({
  required BuildContext context,
  required FlowNode node,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _NodeDetailsDialog(node: node),
  );
}

class _NodeDetailsDialog extends StatelessWidget {
  final FlowNode node;
  const _NodeDetailsDialog({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final (String title, IconData icon, Color iconColor) = _getTitleIconAndColor(node.kind, theme);

    return Center(
      // ... (Widget del ContentDialog rimane invariato)
      child: ContentDialog(
        constraints: const BoxConstraints(
          minWidth: 700,
          maxWidth: 800,
          minHeight: 500,
          maxHeight: 600,
        ),
        content: Container(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // 🎯 Header Section
              Container(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 20),
                decoration: BoxDecoration(
                  color: theme.resources.layerFillColorDefault,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.resources.dividerStrokeColorDefault,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: iconColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: FaIcon(
                        icon,
                        size: 22,
                        color: iconColor,
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Title and Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dettagli $title',
                            style: theme.typography.title?.copyWith(
                              color: theme.typography.body?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Informazioni complete sul nodo selezionato',
                            style: theme.typography.body?.copyWith(
                              color: theme.typography.body?.color?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Node Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        title.toUpperCase(),
                        style: theme.typography.caption?.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 🎯 Content Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - General Info
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoSection(
                              context: context,
                              title: 'Informazioni Generali',
                              children: [
                                _KeyValueDetail(
                                  label: 'Etichetta',
                                  value: node.text.isNotEmpty ? node.text : '–',
                                  theme: theme,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Vertical Divider
                      Container(
                        width: 1,
                        height: double.infinity,
                        color: theme.resources.dividerStrokeColorDefault,
                      ),

                      const SizedBox(width: 24),

                      // Right Column - Specific Details
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildInfoSection(
                            context: context,
                            title: 'Dettagli Specifici',
                            children: _buildSpecificDetails(context, theme),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Centered Action
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Chiudi'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Info Section Builder
  Widget _buildInfoSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    // ... (implementazione invariata)
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.typography.bodyStrong?.copyWith(
            color: theme.typography.body?.color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  /// 🎯 Get Title, Icon and Color for Node Types
  (String, IconData, Color) _getTitleIconAndColor(FlowNodeKind kind, FluentThemeData theme) {
    final accentColor = theme.accentColor.defaultBrushFor(theme.brightness);
    final successColor = theme.brightness == Brightness.light ? const Color(0xFF059669) : const Color(0xFF10B981);
    final warningColor = theme.brightness == Brightness.light ? const Color(0xFFD97706) : const Color(0xFFF59E0B);
    final errorColor = theme.brightness == Brightness.light ? const Color(0xFFDC2626) : const Color(0xFFEF4444);

    return switch (kind) {
      FlowNodeKind.input => ('Nodo Input', FontAwesomeIcons.keyboard, accentColor),
      FlowNodeKind.output => ('Nodo Output', FontAwesomeIcons.terminal, warningColor),
      FlowNodeKind.process => ('Nodo Processo', FontAwesomeIcons.gears, accentColor),
      FlowNodeKind.decision => ('Nodo Condizione', FontAwesomeIcons.codeBranch, warningColor),
      FlowNodeKind.start => ('Nodo Inizio', FontAwesomeIcons.play, successColor),
      FlowNodeKind.end => ('Nodo Fine', FontAwesomeIcons.flagCheckered, errorColor),
    // NUOVO: Aggiunto titolo, icona e colore per il nodo di assegnazione.
      FlowNodeKind.assignment => ('Nodo Assegnazione', FontAwesomeIcons.calculator, accentColor),
    };
  }

  /// 🔍 Build Specific Details based on Node Type
  List<Widget> _buildSpecificDetails(BuildContext context, FluentThemeData theme) {
    switch (node.kind) {
      case FlowNodeKind.input:
      // ... (implementazione invariata)
        final inputNode = node as InputNode;
        return [
          if (inputNode.declarations.isEmpty)
            _EmptyState(
              message: 'Nessuna variabile dichiarata in questo nodo.',
              theme: theme,
            )
          else ...[
            Text(
              'Variabili Dichiarate',
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _BoxedDetail(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: inputNode.declarations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variable = entry.value;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: index < inputNode.declarations.length - 1 ? 12 : 0
                    ),
                    child: Row(
                      children: [
                        // Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            variable.dataType.toUpperCase(),
                            style: TextStyle(
                              color: theme.accentColor.defaultBrushFor(theme.brightness),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Variable Info
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: theme.typography.body?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: theme.typography.body?.color,
                              ),
                              children: [
                                TextSpan(
                                  text: variable.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ];

    // NUOVO: Aggiunto il case per visualizzare i dettagli di AssignmentNode
      case FlowNodeKind.assignment:
        final assignmentNode = node as AssignmentNode;
        return [
          if (assignmentNode.assignments.isEmpty)
            _EmptyState(
              message: 'Nessuna operazione di assegnazione definita.',
              theme: theme,
            )
          else ...[
            Text(
              'Operazioni di Assegnazione',
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _BoxedDetail(
              theme: theme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: assignmentNode.assignments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final assignment = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < assignmentNode.assignments.length - 1 ? 8 : 0,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: theme.typography.body?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: theme.typography.body?.color,
                        ),
                        children: [
                          TextSpan(
                            text: assignment.target,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' = ${assignment.expression}',
                            style: TextStyle(
                              color: theme.typography.body?.color?.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ];

      case FlowNodeKind.output:
      // ... (implementazione invariata)
        final outputNode = node as OutputNode;
        return [
          _KeyValueDetail(
            label: 'Messaggio Template',
            value: outputNode.template.isNotEmpty ? outputNode.template : '–',
            theme: theme,
            isCode: true,
          ),

          const SizedBox(height: 20),

          if (outputNode.variables.isEmpty)
            _EmptyState(
              message: 'Nessuna variabile specificata per l\'output.',
              theme: theme,
            )
          else ...[
            Text(
              'Variabili Utilizzate',
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: outputNode.variables
                  .map((v) => _VariableChip(variable: v, theme: theme))
                  .toList(),
            ),
          ],
        ];

      case FlowNodeKind.process:
      // ... (implementazione invariata)
        final processNode = node as ProcessNode;
        return [
          _KeyValueDetail(
            label: 'Flowchart Chiamato',
            value: processNode.flowchartToCall.isNotEmpty
                ? processNode.flowchartToCall
                : '–',
            theme: theme,
            isMonospace: true,
          ),

          const SizedBox(height: 20),

          if (processNode.arguments.isEmpty)
            _EmptyState(
              message: 'Nessun argomento passato al flowchart.',
              theme: theme,
            )
          else ...[
            Text(
              'Argomenti Passati',
              style: theme.typography.caption?.copyWith(
                color: theme.typography.body?.color?.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: processNode.arguments.asMap().entries.map((entry) {
                final index = entry.key;
                final arg = entry.value;
                return _ArgumentChip(
                  variable: arg,
                  index: index + 1,
                  theme: theme,
                );
              }).toList(),
            ),
          ],

          if (processNode.resultTarget != null) ...[
            const SizedBox(height: 20),
            _buildResultTargetInfo(processNode.resultTarget!, theme),
          ],
        ];

      case FlowNodeKind.decision:
      // ... (implementazione invariata)
        final decisionNode = node as DecisionNode;
        return [
          _BoxedDetail(
            label: 'Condizione',
            value: decisionNode.condition.isNotEmpty
                ? decisionNode.condition
                : '–',
            theme: theme,
            isCode: true,
          ),
        ];

      default:
        return [
          _EmptyState(
            message: 'Nessun dettaglio aggiuntivo disponibile per questo tipo di nodo.',
            theme: theme,
          )
        ];
    }
  }

  /// 🎯 Build Result Target Info for Process Node
  Widget _buildResultTargetInfo(dynamic resultTarget, FluentThemeData theme) {
    // ... (implementazione invariata)
    if (resultTarget is String) {
      // Legacy string format
      return _KeyValueDetail(
        label: 'Variabile di Ritorno',
        value: resultTarget,
        theme: theme,
        isMonospace: true,
      );
    } else if (resultTarget is Map<String, dynamic>) {
      // New typed format
      final name = resultTarget['name'] as String? ?? '–';
      final type = resultTarget['type'] as String? ?? 'void';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Variabile di Ritorno',
            style: theme.typography.caption?.copyWith(
              color: theme.typography.body?.color?.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.resources.layerFillColorAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: TextStyle(
                      color: theme.accentColor.defaultBrushFor(theme.brightness),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Variable Name
                Text(
                  name,
                  style: theme.typography.body?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.typography.body?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return _EmptyState(
      message: 'Formato variabile di ritorno non riconosciuto.',
      theme: theme,
    );
  }
}
/// 🎨 Key-Value Detail Component
class _KeyValueDetail extends StatelessWidget {
  final String label;
  final String value;
  final FluentThemeData theme;
  final bool isMonospace;
  final bool isCode;

  const _KeyValueDetail({
    required this.label,
    required this.value,
    required this.theme,
    this.isMonospace = false,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: theme.typography.body?.color?.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),

        if (isCode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.layerFillColorAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Text(
              value,
              style: theme.typography.body?.copyWith(
                fontFamily: 'monospace',
                fontSize: 13,
                color: theme.typography.body?.color,
              ),
            ),
          )
        else
          Text(
            value,
            style: theme.typography.body?.copyWith(
              fontFamily: isMonospace ? 'monospace' : null,
              fontSize: isMonospace ? 13 : null,
              color: theme.typography.body?.color,
            ),
          ),
      ],
    );
  }
}

/// 🎨 Boxed Detail Component
class _BoxedDetail extends StatelessWidget {
  final String? label;
  final String? value;
  final Widget? child;
  final bool isCode;
  final FluentThemeData theme;

  const _BoxedDetail({
    this.value,
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
          Text(
            label!,
            style: theme.typography.caption?.copyWith(
              color: theme.typography.body?.color?.withOpacity(0.8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.resources.layerFillColorAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
          child: child ??
              Text(
                value == null || value!.isEmpty ? '–' : value!,
                style: theme.typography.body?.copyWith(
                  fontFamily: isCode ? 'monospace' : null,
                  fontSize: isCode ? 13 : null,
                  color: theme.typography.body?.color,
                ),
              ),
        ),
      ],
    );
  }
}

/// 🎨 Variable Chip Component
class _VariableChip extends StatelessWidget {
  final String variable;
  final FluentThemeData theme;

  const _VariableChip({required this.variable, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.3),
        ),
      ),
      child: Text(
        variable,
        style: theme.typography.body?.copyWith(
          color: theme.accentColor.defaultBrushFor(theme.brightness),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 🎨 Argument Chip with Index
class _ArgumentChip extends StatelessWidget {
  final String variable;
  final int index;
  final FluentThemeData theme;

  const _ArgumentChip({
    required this.variable,
    required this.index,
    required this.theme
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.accentColor.defaultBrushFor(theme.brightness).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: theme.accentColor.defaultBrushFor(theme.brightness),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  color: theme.brightness == Brightness.light ? Colors.white : Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            variable,
            style: theme.typography.body?.copyWith(
              color: theme.accentColor.defaultBrushFor(theme.brightness),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 Empty State Component
class _EmptyState extends StatelessWidget {
  final String message;
  final FluentThemeData theme;

  const _EmptyState({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.resources.layerFillColorAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.dividerStrokeColorDefault,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            FaIcon(
              FontAwesomeIcons.circleInfo,
              size: 20,
              color: theme.typography.body?.color?.withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.typography.body?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.typography.body?.color?.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../app_dialogs.dart';
import '../service_dialog.dart';

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
      FlowNodeKind.assignment => ('Nodo Assegnazione', FontAwesomeIcons.calculator, accentColor),
      FlowNodeKind.whileLoop => ('Ciclo While', FontAwesomeIcons.repeat, accentColor),
      FlowNodeKind.doWhileLoop => ('Ciclo Do-While', FontAwesomeIcons.undo, accentColor),
      FlowNodeKind.functionHeader => ('Intestazione Funzione', FontAwesomeIcons.signature, successColor),
      FlowNodeKind.returnNode => ('Nodo Return', FontAwesomeIcons.reply, errorColor),
      // TODO: Handle this case.
      FlowNodeKind.doWhileStart => throw UnimplementedError(),
    };
  }

  /// 🔍 Build Specific Details based on Node Type
  List<Widget> _buildSpecificDetails(BuildContext context, FluentThemeData theme) {
    switch (node.kind) {
      case FlowNodeKind.functionHeader:
        final headerNode = node as FunctionHeaderNode;
        return [
          _KeyValueDetail(
            label: 'Nome Funzione',
            value: headerNode.functionName,
            theme: theme,
            isMonospace: true,
          ),
        ];

      case FlowNodeKind.returnNode:
        final returnNode = node as ReturnNode;
        return [
          _BoxedDetail(
            label: 'Espressione di Ritorno',
            value: returnNode.returnExpression != null && returnNode.returnExpression!.isNotEmpty
                ? returnNode.returnExpression!
                : '(Nessun valore di ritorno)',
            theme: theme,
            isCode: true,
          ),
        ];

      case FlowNodeKind.input:
      // FIX: Aggiornato per usare 'targetVariables' (List<String>) invece di 'declarations'.
        final inputNode = node as InputNode;
        return [
          _TruncatedList(
            title: 'Variabili in Input',
            items: inputNode.targetVariables,
            // La UI ora mostra dei chip, dato che abbiamo solo i nomi.
            itemBuilder: (item) => _VariableChip(variable: item as String, theme: theme),
            displayMode: _TruncatedListDisplayMode.wrap,
            fullListBuilder: (items) => items.cast<String>().join(', '),
          )
        ];

      case FlowNodeKind.assignment:
        final assignmentNode = node as AssignmentNode;
        return [
          _TruncatedList(
            title: 'Operazioni di Assegnazione',
            items: assignmentNode.assignments,
            itemBuilder: (item) {
              final assignment = item as Assignment;
              return RichText(
                text: TextSpan(
                  style: theme.typography.body?.copyWith(fontFamily: 'monospace', fontSize: 13),
                  children: [
                    TextSpan(text: assignment.target, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' = ${assignment.expression}', style: TextStyle(color: theme.typography.body?.color?.withOpacity(0.8))),
                  ],
                ),
              );
            },
            fullListBuilder: (items) {
              return items.map((item) {
                final assignment = item as Assignment;
                return '• ${assignment.target} = ${assignment.expression};';
              }).join('\n');
            },
          )
        ];

      case FlowNodeKind.output:
        final outputNode = node as OutputNode;
        return [
          _KeyValueDetail(label: 'Messaggio Template', value: outputNode.template.isNotEmpty ? outputNode.template : '–', theme: theme, isCode: true),
          const SizedBox(height: 20),
          // FIX: Aggiornato per leggere 'v.name' dall'oggetto VariableDeclaration.
          _TruncatedList(
            title: 'Variabili Utilizzate',
            items: outputNode.variables,
            itemBuilder: (item) {
              final variable = item as VariableDeclaration;
              return _VariableChip(variable: variable.name, theme: theme);
            },
            displayMode: _TruncatedListDisplayMode.wrap,
            fullListBuilder: (items) {
              return items.map((item) => (item as VariableDeclaration).name).join(', ');
            },
          ),
        ];

      case FlowNodeKind.process:
        final processNode = node as ProcessNode;
        return [
          _KeyValueDetail(label: 'Flowchart Chiamato', value: processNode.flowchartToCall.isNotEmpty ? processNode.flowchartToCall : '–', theme: theme, isMonospace: true),
          const SizedBox(height: 20),
          _TruncatedList(
            title: 'Argomenti Passati',
            items: processNode.arguments,
            itemBuilder: (item) {
              final index = processNode.arguments.indexOf(item as String);
              return _ArgumentChip(variable: item, index: index + 1, theme: theme);
            },
            displayMode: _TruncatedListDisplayMode.wrap,
            fullListBuilder: (items) => items.cast<String>().join(', '),
          ),
          if (processNode.resultTarget != null) ...[
            const SizedBox(height: 20),
            _buildResultTargetInfo(processNode.resultTarget!, theme),
          ],
        ];

      case FlowNodeKind.decision:
        final decisionNode = node as DecisionNode;
        return [
          _BoxedDetail(
            label: 'Condizione',
            value: decisionNode.condition.isNotEmpty ? decisionNode.condition : '–',
            theme: theme,
            isCode: true,
          ),
        ];

      case FlowNodeKind.whileLoop:
        final whileNode = node as WhileNode;
        return [
          _BoxedDetail(
            label: 'Condizione (While)',
            value: whileNode.condition.isNotEmpty ? whileNode.condition : '–',
            theme: theme,
            isCode: true,
          ),
        ];

      case FlowNodeKind.doWhileLoop:
        final doWhileNode = node as DoWhileNode;
        return [
          _BoxedDetail(
            label: 'Condizione (Do-While)',
            value: doWhileNode.condition.isNotEmpty ? doWhileNode.condition : '–',
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


/// Enum per definire come visualizzare gli elementi: in colonna o a capo.
enum _TruncatedListDisplayMode { column, wrap }

/// NUOVO: Widget helper per visualizzare liste lunghe in modo troncato.
class _TruncatedList extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final Widget Function(dynamic item) itemBuilder;
  final String Function(List<dynamic> items) fullListBuilder;
  final _TruncatedListDisplayMode displayMode;
  final int maxVisibleItems;

  const _TruncatedList({
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.fullListBuilder,
    this.displayMode = _TruncatedListDisplayMode.column,
    this.maxVisibleItems = 4,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (items.isEmpty) {
      return _EmptyState(message: 'Nessun elemento in questa lista.', theme: theme);
    }

    final visibleItems = items.take(maxVisibleItems).toList();
    final hiddenItemCount = items.length - maxVisibleItems;

    Widget listWidget;
    if (displayMode == _TruncatedListDisplayMode.wrap) {
      listWidget = Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: visibleItems.map((item) => itemBuilder(item)).toList(),
      );
    } else {
      listWidget = _BoxedDetail(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: visibleItems.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: entry.key < visibleItems.length - 1 ? 8 : 0),
              child: itemBuilder(entry.value),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.typography.caption?.copyWith(
            color: theme.typography.body?.color?.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        listWidget,
        if (hiddenItemCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: HoverButton(
              onPressed: () {
                AppDialogs.showInfoDialog(
                  context,
                  title: title,
                  message: fullListBuilder(items),
                  type: DialogType.info,
                );
              },
              builder: (context, states) {
                return Text(
                  '... e altri $hiddenItemCount',
                  style: theme.typography.caption?.copyWith(
                    color: states.isHovering ? theme.accentColor : theme.resources.textFillColorSecondary,
                    decoration: TextDecoration.underline,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// CallStack visual panel showing function call hierarchy graphically.
/// Displays stack frames with caller information, parameters, and return types.
/// Features collapsible frames and visual depth indicators for nested calls.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../blocs/debug_bloc/debug_bloc.dart';
import '../../../../../blocs/debug_bloc/debug_state.dart';

/// Pannello grafico del CallStack che mostra le chiamate a sottoprogrammi.
/// Visualizza i frame dello stack con indicatori visivi di profondità.
class CallStackPanel extends StatelessWidget {
  const CallStackPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<DebugBloc, DebugState>(
      builder: (context, debugState) {
        if (debugState is! DebugInProgress && debugState is! DebugAwaitingInput) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FontAwesomeIcons.layerGroup,
                  size: 48,
                  color: theme.resources.textFillColorTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Call Stack vuoto',
                  style: theme.typography.bodyLarge?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nessun sottoprogramma in esecuzione',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        final callStack = (debugState is DebugInProgress)
            ? debugState.callStack
            : (debugState as DebugAwaitingInput).session.callStack;

        final currentFlowchart = (debugState is DebugInProgress)
            ? debugState.currentFlowchart
            : (debugState as DebugAwaitingInput).currentFlowchart;

        if (callStack.isEmpty) {
          return _buildEmptyStack(theme, currentFlowchart.name);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, callStack),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: callStack.frames.length + 1, // +1 per flowchart corrente
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == callStack.frames.length) {
                    // Frame corrente (in cima allo stack visivo)
                    return _buildCurrentFrame(
                      theme,
                      currentFlowchart,
                      callStack.depth,
                      true,
                    );
                  }

                  final frame = callStack.frames[index];
                  return _buildStackFrame(
                    theme,
                    frame,
                    index,
                    callStack.depth,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Header del pannello con titolo e profondità stack
  Widget _buildHeader(FluentThemeData theme, CallStack callStack) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentColor
                  .defaultBrushFor(theme.brightness)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FaIcon(
              FontAwesomeIcons.layerGroup,
              size: 18,
              color: theme.accentColor.defaultBrushFor(theme.brightness),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Call Stack',
                  style: theme.typography.subtitle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Profondità: ${callStack.depth + 1}',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${callStack.depth + 1}',
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stack vuoto (main in esecuzione)
  Widget _buildEmptyStack(FluentThemeData theme, String mainName) {
    return Column(
      children: [
        _buildHeader(theme, CallStack.empty()),
        const SizedBox(height: 16),
        _buildCurrentFrame(theme, null, 0, false, mainName: mainName),
      ],
    );
  }

  /// Frame corrente (in cima allo stack)
  Widget _buildCurrentFrame(
    FluentThemeData theme,
    Flowchart? flowchart,
    int depth,
    bool isNested, {
    String? mainName,
  }) {
    final name = flowchart?.name ?? mainName ?? 'main';
    final returnType = flowchart?.signature.returnType ?? 'int';
    final params = flowchart?.signature.parameters ?? [];

    return Container(
      margin: EdgeInsets.only(left: depth * 24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accentColor.withValues(alpha: 0.15),
            theme.accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header frame
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                // Indicatore attivo
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: theme.typography.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Text(
                              'CORRENTE',
                              style: theme.typography.caption?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Return: $returnType',
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Parametri (se presenti)
          if (params.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.arrowRight,
                        size: 12,
                        color: theme.resources.textFillColorTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Parametri:',
                        style: theme.typography.caption?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...params.map((param) => Padding(
                        padding: const EdgeInsets.only(left: 20, top: 4),
                        child: Text(
                          '${param.type} ${param.name}',
                          style: theme.typography.caption?.copyWith(
                            fontFamily: 'Consolas',
                            fontSize: 12,
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Frame dello stack (chiamanti)
  Widget _buildStackFrame(
    FluentThemeData theme,
    CallStackFrame frame,
    int index,
    int totalDepth,
  ) {
    return Container(
      margin: EdgeInsets.only(left: index * 24.0),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header frame
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                // Indicatore depth
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.resources.subtleFillColorTertiary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$index',
                    style: theme.typography.caption?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        frame.callerFlowchart.name,
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.arrowRight,
                            size: 10,
                            color: theme.resources.textFillColorTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'chiama ${frame.flowchartName}',
                              style: theme.typography.caption?.copyWith(
                                color: theme.resources.textFillColorSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Parametri passati
          if (frame.parameters.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Argomenti passati:',
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...frame.parameters.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          children: [
                            Text(
                              '${entry.key}: ',
                              style: theme.typography.caption?.copyWith(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: theme.typography.caption?.copyWith(
                                fontFamily: 'Consolas',
                                fontSize: 12,
                                color: theme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

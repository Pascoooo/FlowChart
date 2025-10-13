import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import 'debug_console.dart';
import 'debug_mode/debug_mode.dart';
import 'workarea.dart';

/// 🐛 Debug Mode View - Modalità di debug con validazione runtime
class DebugModeView extends StatefulWidget {
  final GlobalKey workareaKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;

  const DebugModeView({
    super.key,
    required this.workareaKey,
    required this.showGrid,
    required this.onToggleGrid,
  });

  @override
  State<DebugModeView> createState() => _DebugModeViewState();
}

class _DebugModeViewState extends State<DebugModeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  double _consoleHeight = 280.0;
  bool _isDraggingDivider = false;
  double _rightPanelWidth = 0.4;
  bool _isDraggingHorizontalDivider = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FadeTransition(
      opacity: _fade,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final rightWidth = totalWidth * _rightPanelWidth;
          final leftWidth = totalWidth - rightWidth - 8;

          return Row(
            children: [
              // Colonna sinistra - WorkArea + Console
              SizedBox(
                width: leftWidth,
                child: Column(
                  children: [
                    // WorkArea sopra
                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: WorkArea(
                              repaintKey: widget.workareaKey,
                              showGrid: widget.showGrid,
                              onToggleGrid: widget.onToggleGrid,
                              isReadOnly: true,
                              allowDragInReadOnly: false,
                            ),
                          ),

                          // Top Left - Step Info Card
                          const Positioned(
                            top: 24,
                            left: 24,
                            child: DebugStepInfoCard(),
                          ),
                        ],
                      ),
                    ),

                    // Divisore verticale ridimensionabile
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            _consoleHeight = (_consoleHeight - details.delta.dy).clamp(150.0, 500.0);
                          });
                        },
                        onVerticalDragStart: (_) {
                          setState(() => _isDraggingDivider = true);
                        },
                        onVerticalDragEnd: (_) {
                          setState(() => _isDraggingDivider = false);
                        },
                        child: Container(
                          height: 8,
                          color: _isDraggingDivider
                              ? theme.accentColor.withValues(alpha: 0.3)
                              : theme.resources.dividerStrokeColorDefault,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.resources.textFillColorTertiary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Console interattiva sotto (SEMPRE DISPONIBILE per navigazione e comandi)
                    BlocBuilder<FlowchartBloc, FlowchartState>(
                      builder: (context, state) {
                        if (state is! FlowchartLoaded || !state.isDebugMode) {
                          return const SizedBox.shrink();
                        }

                        final currentNodeId = state.selectedNodeId;
                        if (currentNodeId == null) return const SizedBox.shrink();

                        final currentNode = state.getNodeById(currentNodeId);
                        if (currentNode == null) return const SizedBox.shrink();

                        // Console SEMPRE visibile per permettere navigazione con comandi
                        return SizedBox(
                          height: _consoleHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.resources.layerFillColorDefault,
                            ),
                            child: DebugConsole(
                              currentNode: currentNode,
                              flowchartId: state.flowchart.flowchartId,
                              projectRepo: context.read<ProjectBloc>().projectRepository,
                              allVariables: state.flowchart.variables,
                              onCommandExecuted: () {
                                // Avanza automaticamente dopo la valutazione di nodi decisionali/ciclo
                                context.read<FlowchartBloc>().add(const DebugNextNode());
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Divisore orizzontale ridimensionabile
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final delta = details.delta.dx / totalWidth;
                      _rightPanelWidth = (_rightPanelWidth - delta).clamp(0.2, 0.6);
                    });
                  },
                  onHorizontalDragStart: (_) {
                    setState(() => _isDraggingHorizontalDivider = true);
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() => _isDraggingHorizontalDivider = false);
                  },
                  child: Container(
                    width: 8,
                    color: _isDraggingHorizontalDivider
                        ? theme.accentColor.withValues(alpha: 0.3)
                        : theme.resources.dividerStrokeColorDefault,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.resources.textFillColorTertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Colonna destra - Variabili di Sessione
              SizedBox(
                width: rightWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.resources.layerFillColorAlt,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SessionVariablesPanel(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

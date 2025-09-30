import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'node_widget.dart';
import 'painters.dart';

class FlowchartCanvas extends StatelessWidget {
  final bool showGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly; // nuovo

  const FlowchartCanvas({
    super.key,
    required this.showGrid,
    this.isReadOnly = false,
    this.allowDragInReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlowchartBloc, FlowchartState>(
      listener: (context, state) {
        if (state is FlowchartActionFailure) {
          AppDialogs.showInfoDialog(
            context,
            title: state.title,
            message: state.message,
          );
        }
      },
      child: BlocBuilder<FlowchartBloc, FlowchartState>(
        builder: (context, state) {
          if (state is! FlowchartLoaded) {
            return const Center(child: ProgressRing());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Costruiamo il contenuto della canvas (griglia, connessioni, nodi)
              Widget content = GestureDetector(
                onTap: () {
                  context.read<FlowchartBloc>().add(const DeselectNode());
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (showGrid)
                      Positioned.fill(
                        child: CustomPaint(painter: GridPainter.fromTheme(context)),
                      ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(
                          nodes: state.flowchart.nodes,
                          edges: state.flowchart.edges,
                          theme: FluentTheme.of(context),
                        ),
                      ),
                    ),
                    for (final node in state.flowchart.nodes)
                      NodeWidget(
                        key: ValueKey(node.id),
                        node: node,
                        canvasConstraints: constraints,
                        isSelected: state.selectedNodeId == node.id,
                        isReadOnly: isReadOnly,
                        allowDragInReadOnly: allowDragInReadOnly,
                      ),
                  ],
                ),
              );

              // Se siamo in modalità debug, applichiamo zoom + pan animati verso il nodo selezionato
              if (state.isDebugMode && state.selectedNodeId != null) {
                final node = state.getNodeById(state.selectedNodeId!);
                if (node != null) {
                  final viewportW = constraints.maxWidth;
                  final viewportH = constraints.maxHeight;
                  const double targetScale = 1.8;
                  final double nodeCenterX = node.x + node.width / 2;
                  final double nodeCenterY = node.y + (node.height + 42.0) / 2; // include top padding per button
                  final double targetTx = (viewportW / 2) - nodeCenterX * targetScale;
                  final double targetTy = (viewportH / 2) - nodeCenterY * targetScale;

                  // Due TweenAnimationBuilder annidati per animare offset e scala in modo fluido
                  content = ClipRect(
                    child: TweenAnimationBuilder<Offset>(
                      tween: Tween<Offset>(begin: const Offset(0, 0), end: Offset(targetTx, targetTy)),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      key: ValueKey('dbg-offset-${state.selectedNodeId}-${state.debugIndex}'),
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: offset,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 1.0, end: targetScale),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            key: ValueKey('dbg-scale-${state.selectedNodeId}-${state.debugIndex}'),
                            builder: (context, scale, grandChild) {
                              return Transform.scale(
                                scale: scale,
                                alignment: Alignment.topLeft,
                                child: grandChild,
                              );
                            },
                            child: child,
                          ),
                        );
                      },
                      child: content,
                    ),
                  );
                }
              }

              return content;
            },
          );
        },
      ),
    );
  }
}
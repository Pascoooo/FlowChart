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

              // =========================================================================
              // NUOVA LOGICA DI ANIMAZIONE PER IL DEBUG MODE
              // =========================================================================
              if (state.isDebugMode && state.selectedNodeId != null) {
                final node = state.getNodeById(state.selectedNodeId!);
                if (node != null) {
                  final viewportW = constraints.maxWidth;
                  final viewportH = constraints.maxHeight;
                  const double targetScale = 1.8;

                  final double nodeCenterX = node.x + node.width / 2;
                  final double nodeCenterY =
                      node.y + (node.height + 42.0) / 2; // include top padding
                  final double targetTx =
                      (viewportW / 2) - nodeCenterX * targetScale;
                  final double targetTy =
                      (viewportH / 2) - nodeCenterY * targetScale;

                  // Determina se è il primo step per animare lo zoom solo una volta
                  final bool isFirstStep = state.debugIndex == 0;

                  // Se non è il primo step, lo zoom parte dalla scala target per evitare animazioni
                  final double initialScale = isFirstStep ? 1.0 : targetScale;

                  content = ClipRect(
                    child: TweenAnimationBuilder<Offset>(
                      // 1. ANIMA IL PAN (scorrimento) ad ogni cambio di nodo
                      tween: Tween<Offset>(end: Offset(targetTx, targetTy)),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      key: ValueKey('dbg-offset-${state.selectedNodeId}'),
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: offset,
                          child: TweenAnimationBuilder<double>(
                            // 2. ANIMA LO ZOOM solo al primo step
                            tween: Tween<double>(
                                begin: initialScale, end: targetScale),
                            duration: isFirstStep
                                ? const Duration(milliseconds: 400)
                                : Duration.zero,
                            curve: Curves.easeInOut,
                            key: ValueKey(
                                'dbg-scale-${state.flowchart.flowchartId}'),
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
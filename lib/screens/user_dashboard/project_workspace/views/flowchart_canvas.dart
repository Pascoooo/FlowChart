import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/views/node_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart'; // Import corretto

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'creation_handle.dart';
import 'painters.dart';

/// The canvas that renders the flowchart, including nodes, connections, and grid.
class FlowchartCanvas extends StatefulWidget {
  final bool showGrid;
  final bool isReadOnly; // <-- AGGIUNGI QUESTO

  const FlowchartCanvas({super.key, required this.showGrid, this.isReadOnly = false});

  @override
  State<FlowchartCanvas> createState() => _FlowchartCanvasState();
}

class _FlowchartCanvasState extends State<FlowchartCanvas> {
  String? _activeHandleNodeId;

  void _setActiveHandle(String? nodeId) {
    setState(() {
      _activeHandleNodeId = nodeId;
    });
  }

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
            return const Center(child: CircularProgressIndicator());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  final tapPos = details.localPosition;
                  final selectedNode = state.getNodeById(state.selectedNodeId ?? '');

                  if (selectedNode != null) {
                    final extendedRect = Rect.fromLTWH(
                      selectedNode.x - 80,
                      selectedNode.y - 20,
                      selectedNode.width + 160,
                      selectedNode.height + 220,
                    );
                    if (extendedRect.contains(tapPos)) {
                      return; // Non deselezionare, il click è nell'area di interazione
                    }
                  }

                  final tappedOnNode = state.flowchart.nodes.any((node) =>
                      Rect.fromLTWH(node.x, node.y, node.width, node.height)
                          .contains(tapPos));

                  if (!tappedOnNode) {
                    _setActiveHandle(null);
                    context.read<FlowchartBloc>().add(const DeselectNode());
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (widget.showGrid)
                      Positioned.fill(
                        child: CustomPaint(painter: GridPainter.fromTheme(context)),
                      ),

                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(
                          nodes: state.flowchart.nodes,
                          edges: state.flowchart.edges,
                          theme: Theme.of(context),
                        ),
                      ),
                    ),

                    for (final node in state.flowchart.nodes)
                      NodeWidget(
                        key: ValueKey(node.id),
                        node: node,
                        canvasConstraints: constraints,
                        isSelected: state.selectedNodeId == node.id,
                      ),

                    if (state.selectedNodeId != null)
                      ..._buildCreationHandles(context, state, constraints),

                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildCreationHandles(BuildContext context, FlowchartLoaded state, BoxConstraints constraints) {

    if (widget.isReadOnly) return [];

    final selectedNode = state.getNodeById(state.selectedNodeId!);
    if (selectedNode == null) return [];

    // Logica per DecisionNode
    if (selectedNode.kind == FlowNodeKind.decision) {
      final outgoingEdges = state.getOutgoingEdges(selectedNode.id);
      final usedTrue = outgoingEdges.any((e) => e.port == 'true');
      final usedFalse = outgoingEdges.any((e) => e.port == 'false');
      final handles = <Widget>[];

      if (!usedFalse && outgoingEdges.length < 2) {
        handles.add(
          CreationHandle(
            key: ValueKey('handle_left_${selectedNode.id}'),
            direction: HandleDirection.left,
            sourceNode: selectedNode,
            onPanelToggled: (isOpen) => _setActiveHandle(isOpen ? selectedNode.id : null),
            canvasConstraints: constraints,
          ),
        );
      }
      if (!usedTrue && outgoingEdges.length < 2) {
        handles.add(
          CreationHandle(
            key: ValueKey('handle_right_${selectedNode.id}'),
            direction: HandleDirection.right,
            sourceNode: selectedNode,
            onPanelToggled: (isOpen) => _setActiveHandle(isOpen ? selectedNode.id : null),
            canvasConstraints: constraints,
          ),
        );
      }
      return handles;
    }

    // Logica per tutti gli altri nodi
    if (state.canAddOutgoingConnection(selectedNode.id)) {
      return [
        CreationHandle(
          key: ValueKey('canvas_handle_bottom_${selectedNode.id}'),
          direction: HandleDirection.bottom,
          sourceNode: selectedNode,
          onPanelToggled: (isOpen) => _setActiveHandle(isOpen ? selectedNode.id : null),
          canvasConstraints: constraints,
        ),
      ];
    }

    return [];
  }

}
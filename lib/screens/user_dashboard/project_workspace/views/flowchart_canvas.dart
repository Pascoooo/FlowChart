import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'creation_handle.dart';
import 'node_widget.dart';
import 'painters.dart';

/// Il canvas che renderizza l'intero diagramma di flusso,
/// includendo nodi, connessioni e la griglia di sfondo.
class FlowchartCanvas extends StatefulWidget {
  final bool showGrid;
  final bool isReadOnly;

  const FlowchartCanvas({
    super.key,
    required this.showGrid,
    this.isReadOnly = false,
  });

  @override
  State<FlowchartCanvas> createState() => _FlowchartCanvasState();
}

class _FlowchartCanvasState extends State<FlowchartCanvas> {
  /// Traccia quale handle di creazione "+" è attualmente aperto, se presente.
  /// Serve per evitare che un click per chiudere il pannello deselezioni il nodo.
  String? _activeHandleNodeId;

  void _setActiveHandle(String? nodeId) {
    if (mounted) {
      setState(() {
        _activeHandleNodeId = nodeId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlowchartBloc, FlowchartState>(
      // Mostra dialog di errore in caso di azioni non valide
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
                // Gestisce la deselezione quando si clicca sullo sfondo
                onTap: () {
                  // Se un pannello di creazione è aperto, questo click non deve
                  // deselezionare il nodo, ma solo chiudere il pannello.
                  // La logica di chiusura è gestita internamente da CreationHandle.
                  if (_activeHandleNodeId != null) {
                    // Non fare nulla, l'handle gestirà il tap
                  } else {
                    // Nessun pannello aperto, deseleziona qualsiasi nodo
                    context.read<FlowchartBloc>().add(const DeselectNode());
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Livello 1: Griglia di sfondo (opzionale)
                    if (widget.showGrid)
                      Positioned.fill(
                        child:
                        CustomPaint(painter: GridPainter.fromTheme(context)),
                      ),

                    // Livello 2: Connessioni tra i nodi
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(
                          nodes: state.flowchart.nodes,
                          edges: state.flowchart.edges,
                          theme: Theme.of(context),
                        ),
                      ),
                    ),

                    // Livello 3: Widget dei nodi
                    for (final node in state.flowchart.nodes)
                      NodeWidget(
                        key: ValueKey(node.id),
                        node: node,
                        canvasConstraints: constraints,
                        isSelected: state.selectedNodeId == node.id,
                        // **MODIFICA CRUCIALE**: Propaga lo stato di sola lettura al widget del nodo
                        isReadOnly: widget.isReadOnly,
                      ),

                    // Livello 4: Maniglie di creazione "+" per il nodo selezionato
                    if (state.selectedNodeId != null && !widget.isReadOnly)
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

  /// Costruisce le maniglie di creazione (+) attorno al nodo selezionato.
  List<Widget> _buildCreationHandles(
      BuildContext context, FlowchartLoaded state, BoxConstraints constraints) {
    final selectedNode = state.getNodeById(state.selectedNodeId!);
    if (selectedNode == null) return [];

    // Logica per il nodo Condizione (DecisionNode)
    if (selectedNode.kind == FlowNodeKind.decision) {
      final outgoingEdges = state.getOutgoingEdges(selectedNode.id);
      final hasFalseBranch = outgoingEdges.any((e) => e.port == 'false');
      final hasTrueBranch = outgoingEdges.any((e) => e.port == 'true');
      final handles = <Widget>[];

      // Mostra handle 'false' (a sinistra) solo se non esiste già
      if (!hasFalseBranch) {
        handles.add(
          CreationHandle(
            key: ValueKey('handle_left_${selectedNode.id}'),
            direction: HandleDirection.left,
            sourceNode: selectedNode,
            onPanelToggled: (isOpen) =>
                _setActiveHandle(isOpen ? selectedNode.id : null),
            canvasConstraints: constraints,
          ),
        );
      }
      // Mostra handle 'true' (a destra) solo se non esiste già
      if (!hasTrueBranch) {
        handles.add(
          CreationHandle(
            key: ValueKey('handle_right_${selectedNode.id}'),
            direction: HandleDirection.right,
            sourceNode: selectedNode,
            onPanelToggled: (isOpen) =>
                _setActiveHandle(isOpen ? selectedNode.id : null),
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
          onPanelToggled: (isOpen) =>
              _setActiveHandle(isOpen ? selectedNode.id : null),
          canvasConstraints: constraints,
        ),
      ];
    }

    return [];
  }
}
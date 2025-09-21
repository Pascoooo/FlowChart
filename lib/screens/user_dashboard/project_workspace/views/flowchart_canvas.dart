// flowchart_canvas.dart (COMPLETO E AGGIORNATO)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service.dart';
import 'shape_widget.dart';
import 'creation_handle.dart';
import 'painters.dart';
import 'decision_port_handle.dart';

/// Enum defining the direction of a creation handle.
enum HandleDirection { top, right, bottom, left }

/// The canvas that renders the flowchart, including shapes, connections, and grid.
class FlowchartCanvas extends StatefulWidget {
  final bool showGrid;

  const FlowchartCanvas({super.key, required this.showGrid});

  @override
  State<FlowchartCanvas> createState() => _FlowchartCanvasState();
}

class _FlowchartCanvasState extends State<FlowchartCanvas> {
  HandleDirection? _activeHandleDirection;

  void _setActiveHandle(HandleDirection? direction) {
    setState(() {
      _activeHandleDirection = direction;
    });
  }

  // all'interno della classe _FlowchartCanvasState in flowchart_canvas.dart

  @override
  Widget build(BuildContext context) {
    // Usiamo un BlocListener per reagire agli stati "una tantum" come gli errori,
    // senza dover ridisegnare l'intera UI.
    return BlocListener<FlowchartBloc, FlowchartState>(
      listener: (context, state) {
        // Se lo stato emesso è del nostro tipo di errore...
        if (state is FlowchartActionFailure) {
          // ...allora mostriamo il dialogo informativo.
          DialogService.showInfoDialog(
            context,
            title: state.title,
            message: state.message,
          );
        }
      },
      // Il BlocBuilder si occupa solo di disegnare l'interfaccia in base allo stato.
      child: BlocBuilder<FlowchartBloc, FlowchartState>(
        builder: (context, state) {
          // Se lo stato non è 'FlowchartLoaded', mostra un caricamento o uno stato vuoto.
          if (state is! FlowchartLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          // Se lo stato è corretto, costruisci la canvas.
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  final tapPos = details.localPosition;

                  // Se esiste una forma selezionata, calcola una "safe zone" estesa intorno
                  // alla forma + area dove appaiono handle e pannello per evitare
                  // deselezioni accidentali quando si tenta di premere il pulsante "+" o le opzioni.
                  if (state.selectedShapeId != null) {
                    final sel = state.shapes.firstWhere(
                      (s) => s.id == state.selectedShapeId,
                      orElse: () => const FlowchartShape(id: 'missing', type: 'processo', x: 0, y: 0, width: 0, height: 0, text: ''),
                    );
                    if (sel.id != 'missing') {
                      // Estendiamo il rettangolo: lateralmente +80, in basso +220 (handle + pannello)
                      final extendedRect = Rect.fromLTWH(
                        sel.x - 80,
                        sel.y - 20, // piccolo margine sopra
                        sel.width + 160,
                        sel.height + 220,
                      );
                      if (extendedRect.contains(tapPos)) {
                        // Non deselezionare: il tap è correlato alla zona di interazione corrente
                        return;
                      }
                    }
                  }

                  // Deseleziona solo se il tap NON è su alcuna forma
                  final tappedShape = state.shapes.any((s) =>
                      tapPos.dx >= s.x &&
                      tapPos.dx <= s.x + s.width &&
                      tapPos.dy >= s.y &&
                      tapPos.dy <= s.y + s.height);
                  if (!tappedShape) {
                    _setActiveHandle(null);
                    context.read<FlowchartBloc>().add(DeselectShape());
                  }
                },
                // Rimosso il vecchio onTap che causava deselezione immediata
                behavior: HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Grid
                    if (widget.showGrid)
                      Positioned.fill(
                        child: CustomPaint(painter: GridPainter.fromTheme(context)),
                      ),

                    // Connections
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(
                          shapes: state.shapes,
                          connections: state.connections,
                          theme: Theme.of(context),
                        ),
                      ),
                    ),

                    // Shapes
                    for (final shape in state.shapes)
                      ShapeWidget(
                        key: ValueKey(shape.id),
                        shape: shape,
                        canvasConstraints: constraints,
                        isSelected: state.selectedShapeId == shape.id,
                      ),

                    // Unico handle standard o doppi handle per decision
                    if (state.selectedShapeId != null)
                      for (final shape in state.shapes)
                        if (shape.id == state.selectedShapeId)
                          if (shape.type == 'condizione') ...[
                            Builder(builder: (_) {
                              // Determina quali porte (true/right, false/left) sono già usate
                              final conns = state.connections.where((c) => c.fromShapeId == shape.id);
                              final usedTrue = conns.any((c) => c.fromPort == 'true');
                              final usedFalse = conns.any((c) => c.fromPort == 'false');
                              final handles = <Widget>[];
                              if (!usedFalse && shape.outgoingConnectionIds.length < shape.maxOutgoingConnections) {
                                handles.add(
                                  CreationHandle(
                                    key: ValueKey('handle_left_${shape.id}'),
                                    direction: HandleDirection.left,
                                    sourceShape: shape,
                                    onPanelToggled: _setActiveHandle,
                                    canvasConstraints: constraints,
                                  ),
                                );
                              }
                              if (!usedTrue && shape.outgoingConnectionIds.length < shape.maxOutgoingConnections) {
                                handles.add(
                                  CreationHandle(
                                    key: ValueKey('handle_right_${shape.id}'),
                                    direction: HandleDirection.right,
                                    sourceShape: shape,
                                    onPanelToggled: _setActiveHandle,
                                    canvasConstraints: constraints,
                                  ),
                                );
                              }
                              return Stack(children: handles);
                            })
                          ] else if (shape.canAddOutgoingConnection)
                            CreationHandle(
                              key: ValueKey('canvas_handle_bottom_${shape.id}'),
                              direction: HandleDirection.bottom,
                              sourceShape: shape,
                              onPanelToggled: _setActiveHandle,
                              canvasConstraints: constraints,
                            ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
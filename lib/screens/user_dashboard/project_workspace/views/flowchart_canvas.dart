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
                onTap: _activeHandleDirection == null
                    ? () {
                  _setActiveHandle(null);
                  context.read<FlowchartBloc>().add(DeselectShape());
                }
                    : null,
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

                    // Maniglie di creazione per la forma selezionata
                    if (state.selectedShapeId != null)
                      for (final shape in state.shapes)
                        if (shape.id == state.selectedShapeId && shape.canAddOutgoingConnection)
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
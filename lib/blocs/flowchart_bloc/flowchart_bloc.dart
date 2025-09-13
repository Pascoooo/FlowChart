// pascoooo/flowchart/FlowChart-rework/lib/blocs/flowchart_bloc/flowchart_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'flowchart_event.dart';
import 'flowchart_state.dart';

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  FlowchartBloc() : super(FlowchartInitial()) {
    on<LoadFlowchart>(_onLoadFlowchart);
    on<AddShape>(_onAddShape);
    on<RemoveShape>(_onRemoveShape);
    on<UpdateShape>(_onUpdateShape);
    on<SelectShape>(_onSelectShape);
    on<DeselectShape>(_onDeselectShape);
  }

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    emit(FlowchartLoaded.fromJson(event.jsonContent));
  }

  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final updatedShapes = List<FlowchartShape>.from(currentState.shapes)
        ..add(event.shape);
      emit(
        FlowchartLoaded(
          shapes: updatedShapes,
          selectedShapeId: event.shape.id,
        ),
      );
    } else {
      emit(
        FlowchartLoaded(
          shapes: [event.shape],
          selectedShapeId: event.shape.id,
        ),
      );
    }
  }

  void _onRemoveShape(RemoveShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final updatedShapes =
      currentState.shapes.where((s) => s.id != event.shapeId).toList();
      emit(
        FlowchartLoaded(
          shapes: updatedShapes,
          selectedShapeId: currentState.selectedShapeId == event.shapeId
              ? null
              : currentState.selectedShapeId,
        ),
      );
    }
  }

  void _onUpdateShape(UpdateShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final updatedShapes = currentState.shapes.map((shape) {
        if (shape.id == event.shapeId) {
          return shape.copyWith(x: event.newX, y: event.newY);
        }
        return shape;
      }).toList();
      emit(FlowchartLoaded(
        shapes: updatedShapes,
        selectedShapeId: currentState.selectedShapeId,
      ));
    }
  }

  void _onSelectShape(SelectShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      emit(
        FlowchartLoaded(
          shapes: currentState.shapes,
          selectedShapeId: event.shapeId,
        ),
      );
    }
  }

  void _onDeselectShape(DeselectShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      emit(
        FlowchartLoaded(
          shapes: currentState.shapes,
          selectedShapeId: null,
        ),
      );
    }
  }
}
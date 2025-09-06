// flowchart_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'flowchart_event.dart';
import 'flowchart_state.dart';

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  FlowchartBloc() : super(FlowchartInitial()) {
    on<AddShape>((event, emit) {
      final currentState = state;
      if (currentState is FlowchartLoaded) {
        emit(
          FlowchartLoaded(
            shapes: List.from(currentState.shapes)..add(event.shape),
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
    });

    on<RemoveShape>((event, emit) {
      final currentState = state;
      if (currentState is FlowchartLoaded) {
        emit(
          FlowchartLoaded(
            shapes: currentState.shapes.where((s) => s.id != event.shapeId).toList(),
            selectedShapeId: currentState.selectedShapeId == event.shapeId ? null : currentState.selectedShapeId,
          ),
        );
      }
    });

    on<SelectShape>((event, emit) {
      final currentState = state;
      if (currentState is FlowchartLoaded) {
        emit(
          FlowchartLoaded(
            shapes: currentState.shapes,
            selectedShapeId: event.shapeId,
          ),
        );
      }
    });

    on<DeselectShape>((event, emit) {
      final currentState = state;
      if (currentState is FlowchartLoaded) {
        emit(
          FlowchartLoaded(
            shapes: currentState.shapes,
            selectedShapeId: null,
          ),
        );
      }
    });
  }
}

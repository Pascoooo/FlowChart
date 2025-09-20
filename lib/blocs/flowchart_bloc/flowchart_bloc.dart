import 'dart:ui';
import 'package:flowchart_thesis/blocs/flowchart_bloc/placement_engine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart';
import 'commands/command_history.dart';
import 'flowchart_event.dart';
import 'flowchart_state.dart';
import 'commands/flowchart_command.dart';

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  final CommandHistory _history = CommandHistory();

  FlowchartBloc() : super(FlowchartInitial()) {
    on<LoadFlowchart>(_onLoadFlowchart);
    on<AddShape>(_onAddShape);
    on<RemoveShape>(_onRemoveShape);
    on<UpdateShape>(_onUpdateShape);
    on<SelectShape>(_onSelectShape);
    on<DeselectShape>(_onDeselectShape);
    on<UndoCommand>(_onUndo);
    on<RedoCommand>(_onRedo);
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get nextUndoDescription => _history.nextUndoCommand?.description;
  String? get nextRedoDescription => _history.nextRedoCommand?.description;

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    emit(FlowchartLoaded.fromJson(event.jsonContent));
  }

  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final validator = FlowchartValidator();

    final shapeValidationResult = validator.validate(currentState, event.shape);
    if (!shapeValidationResult.isValid) {
      print("VALIDATION FAILED (Shape): ${shapeValidationResult.errorMessage}");
      return;
    }

    final fromShape = currentState.shapes.firstWhere(
          (s) => s.id == event.fromShapeId,
      // --- CORREZIONE QUI ---
      // Ho sostituito .empty() con il costruttore completo di una forma vuota.
      orElse: () => const FlowchartShape(id: '', type: '', text: '', x: 0, y: 0, width: 0, height: 0),
    );
    if (fromShape.id.isEmpty) return;

    const newShapeSize = Size(120, 60);
    final optimalPosition = PlacementEngine.findOptimalPosition(
      fromShape: fromShape,
      newShapeSize: newShapeSize,
      existingShapes: currentState.shapes,
    );
    if (optimalPosition == null) {
      print("PLACEMENT ERROR: Spazio insufficiente.");
      return;
    }

    final newShape = event.shape.copyWith(
      x: optimalPosition.dx, y: optimalPosition.dy,
      width: newShapeSize.width, height: newShapeSize.height,
    );
    final newConnection = FlowchartConnection(
      fromShapeId: fromShape.id, toShapeId: newShape.id, id: const Uuid().v4(),
    );

    final connectionValidationResult = validator.validate(currentState, newConnection);
    if (!connectionValidationResult.isValid) {
      print("VALIDATION FAILED (Connection): ${connectionValidationResult.errorMessage}");
      return;
    }

    final command = CompositeCommand(
      [ AddShapeCommand(newShape), AddConnectionCommand(newConnection) ],
      'Aggiungi forma',
    );
    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onRemoveShape(RemoveShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is! FlowchartLoaded) return;
    if (event.shapeId.startsWith('start_')) return;

    final shapeToRemove = currentState.shapes.firstWhere((s) => s.id == event.shapeId);

    final connectionsToRemove = currentState.connections
        .where((c) => c.fromShapeId == event.shapeId || c.toShapeId == event.shapeId)
        .toList();

    final List<FlowchartCommand> commands = [
      RemoveShapeCommand(shapeToRemove)
    ];
    for (final conn in connectionsToRemove) {
      commands.add(RemoveConnectionCommand(conn));
    }

    final command = CompositeCommand(commands, 'Rimuovi forma');
    _history.executeCommand(command);

    emit(command.execute(currentState).deselect());
  }

  void _onUpdateShape(UpdateShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final oldShape = currentState.shapes.firstWhere((s) => s.id == event.shapeId);
      final command = MoveShapeCommand(
        shapeId: event.shapeId,
        newX: event.newX, newY: event.newY,
        oldX: event.oldX ?? oldShape.x, oldY: event.oldY ?? oldShape.y,
      );
      if (command.oldX != command.newX || command.oldY != command.newY) {
        _history.executeCommand(command);
      }
      emit(command.execute(currentState));
    }
  }

  void _onSelectShape(SelectShape event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).copyWith(selectedShapeId: event.shapeId));
    }
  }

  void _onDeselectShape(DeselectShape event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).deselect());
    }
  }

  void _onUndo(UndoCommand event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.undo();
      if (command != null) {
        emit(command.undo(state as FlowchartLoaded));
      }
    }
  }

  void _onRedo(RedoCommand event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.redo();
      if (command != null) {
        emit(command.execute(state as FlowchartLoaded));
      }
    }
  }
}
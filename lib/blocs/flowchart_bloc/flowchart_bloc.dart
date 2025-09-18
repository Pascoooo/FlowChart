// lib/blocs/flowchart_bloc/flowchart_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<ExecuteCommand>(_onExecuteCommand);
    on<ClearHistory>(_onClearHistory);
    on<ResetFlowchart>(_onResetFlowchart);
  }

  /// Getter per accedere alle informazioni di undo/redo dall'UI
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get nextUndoDescription => _history.nextUndoCommand?.description;
  String? get nextRedoDescription => _history.nextRedoCommand?.description;

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    emit(FlowchartLoaded.fromJson(event.jsonContent));
  }

  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final command = AddShapeCommand(event.shape);
      _history.executeCommand(command);

      final newState = command.execute(currentState).copyWith(
        selectedShapeId: event.shape.id,
      );
      emit(newState);
    } else {
      // Se non c'è uno stato caricato, crea un nuovo stato
      final command = AddShapeCommand(event.shape);
      _history.executeCommand(command);

      emit(FlowchartLoaded(
        shapes: [event.shape],
        selectedShapeId: event.shape.id,
      ));
    }
  }

  void _onRemoveShape(RemoveShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      if (event.shapeId.startsWith('start_')) {
        return;
      }
      final shapeToRemove = currentState.shapes.firstWhere(
            (s) => s.id == event.shapeId,
        orElse: () => throw StateError('Shape not found'),
      );
      final command = RemoveShapeCommand(shapeToRemove, currentState.selectedShapeId);
      _history.executeCommand(command);

      final newState = command.execute(currentState);
      emit(newState);
    }
  }

  void _onUpdateShape(UpdateShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      // Trova la posizione precedente per l'undo
      final oldShape = currentState.shapes.firstWhere((s) => s.id == event.shapeId);
      final oldX = event.oldX ?? oldShape.x;
      final oldY = event.oldY ?? oldShape.y;

      final command = MoveShapeCommand(
        shapeId: event.shapeId,
        newX: event.newX,
        newY: event.newY,
        oldX: oldX,
        oldY: oldY,
      );

      // Esegui il comando solo se la posizione è effettivamente cambiata
      if (oldX != event.newX || oldY != event.newY) {
        _history.executeCommand(command);
      }

      final newState = command.execute(currentState);
      emit(newState);
    }
  }

  void _onSelectShape(SelectShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      emit(currentState.withSelection(event.shapeId));
    }
  }

  void _onDeselectShape(DeselectShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      emit(currentState.clearSelection());
    }
  }

  void _onUndo(UndoCommand event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final command = _history.undo();
      if (command != null) {
        final newState = command.undo(currentState);
        emit(newState);
      }
    }
  }

  void _onRedo(RedoCommand event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      final command = _history.redo();
      if (command != null) {
        final newState = command.execute(currentState);
        emit(newState);
      }
    }
  }

  void _onExecuteCommand(ExecuteCommand event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      _history.executeCommand(event.command);
      final newState = event.command.execute(currentState);
      emit(newState);
    }
  }

  void _onResetFlowchart(ResetFlowchart event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      // Trova tutte le forme che NON sono la forma "Start"
      final shapesToRemove = currentState.shapes
          .where((shape) => !shape.id.startsWith('start_'))
          .toList();
      if (shapesToRemove.isEmpty) return;
      final commands = shapesToRemove.map((shape) => RemoveShapeCommand(shape, currentState.selectedShapeId)).toList();
      final compositeCommand = CompositeCommand(commands, 'Reset Flowchart');

      _history.executeCommand(compositeCommand);
      final newState = compositeCommand.execute(currentState);
      emit(newState);
    }
  }

  void _onClearHistory(ClearHistory event, Emitter<FlowchartState> emit) {
    _history.clear();
  }
}
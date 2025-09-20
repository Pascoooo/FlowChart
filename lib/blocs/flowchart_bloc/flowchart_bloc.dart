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
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get nextUndoDescription => _history.nextUndoCommand?.description;
  String? get nextRedoDescription => _history.nextRedoCommand?.description;

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    emit(FlowchartLoaded.fromJson(event.jsonContent));
  }

// in flowchart_bloc.dart
  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is! FlowchartLoaded) return;

    print("BLOC: Ricevuto evento AddShape da ${event.fromShapeId}"); // <-- LOG 1

    final List<FlowchartCommand> commands = [AddShapeCommand(event.shape)];
    String description = 'Aggiungi forma';

    if (event.fromShapeId != null) {
      final connection = FlowchartConnection(
        id: 'conn_${DateTime.now().microsecondsSinceEpoch}',
        fromShapeId: event.fromShapeId!,
        toShapeId: event.shape.id,
      );
      commands.add(AddConnectionCommand(connection));
      description = 'Aggiungi forma e connessione';
    }

    final command = CompositeCommand(commands, description);
    _history.executeCommand(command);

    // -- SEZIONE DI DEBUG --
    print("BLOC: Stato PRIMA dell'esecuzione: ${currentState.shapes.length} forme, ${currentState.connections.length} connessioni."); // <-- LOG 2

    final newState = command.execute(currentState).copyWith(
      selectedShapeId: event.shape.id,
    );

    print("BLOC: Stato DOPO l'esecuzione: ${newState.shapes.length} forme, ${newState.connections.length} connessioni."); // <-- LOG 3
    // -- FINE SEZIONE DI DEBUG --

    emit(newState);
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

    final command = CompositeCommand(commands, 'Rimuovi forma e connessioni');
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
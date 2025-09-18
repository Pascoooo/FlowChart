import 'package:flutter_bloc/flutter_bloc.dart';
import 'commands/command_history.dart';
import 'flowchart_event.dart';
import 'flowchart_state.dart';
import 'commands/flowchart_command.dart';

/// Gestisce lo stato e la logica di business per l'editor di flowchart.
/// Utilizza un Command Pattern per supportare operazioni di undo/redo.
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

  /// Indica se è possibile eseguire un'operazione di undo.
  bool get canUndo => _history.canUndo;

  /// Indica se è possibile eseguire un'operazione di redo.
  bool get canRedo => _history.canRedo;

  /// Ritorna la descrizione del prossimo comando che verrà annullato.
  String? get nextUndoDescription => _history.nextUndoCommand?.description;

  /// Ritorna la descrizione del prossimo comando che verrà rieseguito.
  String? get nextRedoDescription => _history.nextRedoCommand?.description;

  /// Carica un flowchart da una stringa JSON, resettando la cronologia.
  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    _history.clear();
    emit(FlowchartLoaded.fromJson(event.jsonContent));
  }

  /// Aggiunge una nuova forma, la seleziona e registra il comando nella cronologia.
  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    final command = AddShapeCommand(event.shape);
    _history.executeCommand(command);

    FlowchartLoaded newState;
    if (state is FlowchartLoaded) {
      newState = (state as FlowchartLoaded)
          .copyWith(shapes: command.execute(state as FlowchartLoaded).shapes)
          .copyWith(selectedShapeId: event.shape.id);
    } else {
      newState = FlowchartLoaded(
          shapes: [event.shape], selectedShapeId: event.shape.id);
    }
    emit(newState);
  }

  /// Rimuove una forma e registra il comando nella cronologia.
  /// Impedisce la rimozione della forma "Start".
  void _onRemoveShape(RemoveShape event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    if (event.shapeId.startsWith('start_')) return;

    final shapeToRemove =
    currentState.shapes.firstWhere((s) => s.id == event.shapeId);
    final command =
    RemoveShapeCommand(shapeToRemove, currentState.selectedShapeId);
    _history.executeCommand(command);

    emit(command.execute(currentState));
  }

  /// Aggiorna la posizione di una forma. Aggiunge il comando alla cronologia
  /// solo alla fine di un'operazione di trascinamento.
  void _onUpdateShape(UpdateShape event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final oldShape =
    currentState.shapes.firstWhere((s) => s.id == event.shapeId);
    final oldX = event.oldX ?? oldShape.x;
    final oldY = event.oldY ?? oldShape.y;

    final command = MoveShapeCommand(
      shapeId: event.shapeId,
      newX: event.newX,
      newY: event.newY,
      oldX: oldX,
      oldY: oldY,
    );

    if (oldX != event.newX || oldY != event.newY) {
      _history.executeCommand(command);
    }

    emit(command.execute(currentState));
  }

  /// Seleziona una forma. Questa è un'operazione di UI e non viene registrata.
  void _onSelectShape(SelectShape event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).copyWith(selectedShapeId: event.shapeId));
    }
  }

  /// Deseleziona qualsiasi forma. Questa è un'operazione di UI e non viene registrata.
  void _onDeselectShape(DeselectShape event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      emit((state as FlowchartLoaded).copyWith(clearSelection: true));
    }
  }

  /// Annulla l'ultimo comando eseguito.
  void _onUndo(UndoCommand event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.undo();
      if (command != null) {
        emit(command.undo(state as FlowchartLoaded));
      }
    }
  }

  /// Riesegue l'ultimo comando annullato.
  void _onRedo(RedoCommand event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      final command = _history.redo();
      if (command != null) {
        emit(command.execute(state as FlowchartLoaded));
      }
    }
  }

  /// Esegue un comando generico e lo aggiunge alla cronologia.
  void _onExecuteCommand(ExecuteCommand event, Emitter<FlowchartState> emit) {
    if (state is FlowchartLoaded) {
      _history.executeCommand(event.command);
      emit(event.command.execute(state as FlowchartLoaded));
    }
  }

  /// Rimuove tutte le forme tranne quella "Start", registrando un unico comando composito.
  void _onResetFlowchart(ResetFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    final shapesToRemove =
    currentState.shapes.where((s) => !s.id.startsWith('start_')).toList();
    if (shapesToRemove.isEmpty) return;

    final commands = shapesToRemove
        .map((shape) => RemoveShapeCommand(shape, currentState.selectedShapeId))
        .toList();
    final compositeCommand = CompositeCommand(commands, 'Reset Flowchart');

    _history.executeCommand(compositeCommand);
    emit(compositeCommand.execute(currentState));
  }

  /// Pulisce la cronologia di undo/redo, tipicamente al caricamento di un nuovo file.
  void _onClearHistory(ClearHistory event, Emitter<FlowchartState> emit) {
    _history.clear();
  }
}
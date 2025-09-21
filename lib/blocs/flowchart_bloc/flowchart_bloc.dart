import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'FlowchartShapeFactory.dart';
import 'placement_engine.dart';
import 'commands/command_history.dart';
import 'flowchart_event.dart';
import 'flowchart_state.dart';
import 'commands/flowchart_command.dart';
import '../../screens/user_dashboard/project_workspace/views/rules/flowchart_rule.dart';

class FlowchartBloc extends Bloc<FlowchartEvent, FlowchartState> {
  final CommandHistory _history = CommandHistory();

  FlowchartBloc() : super(FlowchartInitial()) {
    on<LoadFlowchart>(_onLoadFlowchart);
    on<AddShape>(_onAddShape);
    on<RemoveShape>(_onRemoveShape);
    on<UpdateShape>(_onUpdateShape); // CORREZIONE: Registrazione handler
    on<UpdateShapeProperties>(_onUpdateShapeProperties);
    on<SelectShape>(_onSelectShape);
    on<DeselectShape>(_onDeselectShape);
    on<UndoCommand>(_onUndo);
    on<RedoCommand>(_onRedo);
    on<ResetFlowchart>(_onResetFlowchart); // NUOVO
    on<LinkToExistingEnd>(_onLinkToExistingEnd); // NUOVO
  }

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  String? get nextUndoDescription => _history.nextUndoCommand?.description;
  String? get nextRedoDescription => _history.nextRedoCommand?.description;

  void _onLoadFlowchart(LoadFlowchart event, Emitter<FlowchartState> emit) {
    final previous = state is FlowchartLoaded ? state as FlowchartLoaded : null;
    final loaded = FlowchartLoaded.fromJson(event.jsonContent);

    String? preservedSelection;
    if (previous != null && previous.selectedShapeId != null) {
      if (loaded.shapes.any((s) => s.id == previous.selectedShapeId)) {
        preservedSelection = previous.selectedShapeId;
      }
    }

    // Funzione locale per migrare connessioni senza fromPort da decision
    List<FlowchartConnection> _migrateMissingPorts(FlowchartLoaded base, List<FlowchartConnection> conns) {
      final shapeMap = {for (final s in base.shapes) s.id: s};
      bool changed = false;
      final migrated = conns.map((c) {
        if (c.fromPort == null) {
          final fromShape = shapeMap[c.fromShapeId];
            final toShape = shapeMap[c.toShapeId];
          if (fromShape != null && toShape != null && fromShape.type == 'condizione') {
            final fromCenterX = fromShape.x + fromShape.width / 2;
            final toCenterX = toShape.x + toShape.width / 2;
            final inferred = toCenterX >= fromCenterX ? 'true' : 'false';
            changed = true;
            return FlowchartConnection(
              id: c.id,
              fromShapeId: c.fromShapeId,
              toShapeId: c.toShapeId,
              fromPort: inferred,
            );
          }
        }
        return c;
      }).toList();
      return changed ? migrated : conns;
    }

    if (previous != null) {
      // Merge: preserva fromPort esistenti
      List<FlowchartConnection> mergedConnections = loaded.connections.map((c) {
        if (c.fromPort == null) {
          try {
            final old = previous.connections.firstWhere((oc) => oc.id == c.id);
            if (old.fromPort != null) {
              return FlowchartConnection(
                id: c.id,
                fromShapeId: c.fromShapeId,
                toShapeId: c.toShapeId,
                fromPort: old.fromPort,
              );
            }
          } catch (_) {}
        }
        return c;
      }).toList();

      // Migrazione per connessioni legacy da decision senza fromPort
      mergedConnections = _migrateMissingPorts(loaded, mergedConnections);

      FlowchartLoaded mergedState = loaded;
      if (mergedConnections != loaded.connections) {
        mergedState = loaded.copyWith(connections: mergedConnections);
      }
      if (preservedSelection != null) {
        mergedState = mergedState.copyWith(selectedShapeId: preservedSelection);
      }
      emit(mergedState);
    } else {
      // Prima apertura: migrazione se necessario
      final migrated = _migrateMissingPorts(loaded, loaded.connections);
      final base = (migrated != loaded.connections)
          ? loaded.copyWith(connections: migrated)
          : loaded;
      emit(base.copyWith(selectedShapeId: preservedSelection));
    }
  }

// all'interno della classe FlowchartBloc in flowchart_bloc.dart

  void _onAddShape(AddShape event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;
    final validator = FlowchartValidator();

    // 1. Usa la Factory per creare una forma "potenziale" (la posizione è temporanea)
    final potentialShape = FlowchartShapeFactory.createShape(event.shapeType, Offset.zero);

    // 2. Valida il TIPO di forma che si sta per aggiungere
    final shapeValidationResult = validator.validate(currentState, potentialShape);
    if (!shapeValidationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Azione non permessa",
        message: shapeValidationResult.errorMessage ?? "Non puoi aggiungere questo tipo di forma.",
      ));
      emit(currentState); // Ripristina lo stato precedente
      return;
    }

    // 3. Cerca la forma di partenza in modo sicuro
    FlowchartShape fromShape;
    try {
      fromShape = currentState.shapes.firstWhere((s) => s.id == event.fromShapeId);
    } catch (e) {
      return;
    }

    // 4. Calcolo posizione: caso speciale per decision + porti true/false
    Offset? optimalPosition;
    if (fromShape.type == 'condizione' && event.fromPort != null) {
      final newW = potentialShape.width;
      final newH = potentialShape.height;
      double newX;
      double newY = fromShape.y + (fromShape.height - newH) / 2;
      if (event.fromPort == 'true') {
        newX = fromShape.x + fromShape.width + 40; // leggera distanza dal vertice destro
      } else { // 'false'
        newX = fromShape.x - newW - 40; // a sinistra del vertice sinistro
      }
      optimalPosition = Offset(newX, newY);
      // Controllo collisioni semplice: se overlap forte con un'altra shape, fallback al placement engine standard (sotto)
      final overlaps = currentState.shapes.any((s) =>
        !(newX + newW < s.x || newX > s.x + s.width || newY + newH < s.y || newY > s.y + s.height)
      );
      if (overlaps) {
        optimalPosition = null; // forziamo fallback
      }
    }

    optimalPosition ??= PlacementEngine.findOptimalPosition(
        fromShape: fromShape,
        newShapeSize: Size(potentialShape.width, potentialShape.height),
        existingShapes: currentState.shapes,
        canvasConstraints: event.canvasConstraints,
      );

    // 5. Se non trova spazio, emetti lo stato di errore per la UI
    if (optimalPosition == null) {
      emit(const FlowchartActionFailure(
        title: "Posizione non disponibile",
        message: "Non c'è spazio sufficiente per aggiungere una nuova forma qui.",
      ));
      emit(currentState); // Ripristina lo stato precedente
      return;
    }

    // 6. Crea la forma e la connessione finali
    final newShape = potentialShape.copyWith(x: optimalPosition.dx, y: optimalPosition.dy);
    final newConnection = FlowchartConnection(
      id: const Uuid().v4(),
      fromShapeId: fromShape.id,
      toShapeId: newShape.id,
      fromPort: event.fromPort,
    );

    // 7. Valida la nuova connessione che si sta per creare
    final connectionValidationResult = validator.validate(currentState, newConnection);
    if (!connectionValidationResult.isValid) {
      emit(FlowchartActionFailure(
        title: "Connessione non permessa",
        message: connectionValidationResult.errorMessage ?? "Questa connessione viola le regole del diagramma.",
      ));
      emit(currentState); // Ripristina lo stato precedente
      return;
    }

    // 8. Se tutto è valido, esegui il comando per aggiornare lo stato
    final command = CompositeCommand(
      [AddShapeCommand(newShape), AddConnectionCommand(newConnection)],
      'Aggiungi forma',
    );

    _history.executeCommand(command);
    emit(command.execute(currentState));
  }

  void _onRemoveShape(RemoveShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is! FlowchartLoaded) return;

    FlowchartShape shapeToRemove;
    try {
      shapeToRemove = currentState.shapes.firstWhere((s) => s.id == event.shapeId);
    } catch (e) {
      return; // La forma non esiste, non fare nulla
    }

    // Identifica eventuale padre (connessione in ingresso) PRIMA di rimuovere le connessioni
    final incomingConns = currentState.connections
        .where((c) => c.toShapeId == shapeToRemove.id)
        .toList();
    String? parentId;
    if (incomingConns.length == 1) {
      parentId = incomingConns.first.fromShapeId;
    }

    final commands = <FlowchartCommand>[RemoveShapeCommand(shapeToRemove)];

    final connectionsToRemove = currentState.connections
        .where((c) => c.fromShapeId == event.shapeId || c.toShapeId == event.shapeId)
        .toList();

    for (final conn in connectionsToRemove) {
      commands.add(RemoveConnectionCommand(conn));
    }

    final command = CompositeCommand(commands, 'Rimuovi forma');
    _history.executeCommand(command);
    final newState = command.execute(currentState);

    // Se possibile seleziona il padre (che ora ha liberato lo slot in uscita)
    if (parentId != null && newState.shapes.any((s) => s.id == parentId)) {
      emit(newState.copyWith(selectedShapeId: parentId));
    } else {
      emit(newState.deselect());
    }
  }

  // CORREZIONE: Implementazione completa del gestore
  void _onUpdateShape(UpdateShape event, Emitter<FlowchartState> emit) {
    final currentState = state;
    if (currentState is FlowchartLoaded) {
      FlowchartShape oldShape;
      try {
        oldShape = currentState.shapes.firstWhere((s) => s.id == event.shapeId);
      } catch (e) { return; }

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

  void _onUpdateShapeProperties(UpdateShapeProperties event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final currentState = state as FlowchartLoaded;

    FlowchartShape oldShape;
    try {
      oldShape = currentState.shapes.firstWhere((s) => s.id == event.shapeId);
    } catch (e) { return; }

    final command = UpdateShapePropertiesCommand(
      shapeId: event.shapeId,
      newText: event.text,
      oldText: oldShape.text,
    );
    _history.executeCommand(command);
    emit(command.execute(currentState));
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

  void _onResetFlowchart(ResetFlowchart event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final current = state as FlowchartLoaded;

    // Trova uno start esistente oppure creane uno nuovo
    FlowchartShape? startShape;
    try {
      startShape = current.shapes.firstWhere((s) => s.type == 'start');
      // Pulisce le liste delle connessioni mantenendo dimensioni e posizione
      startShape = startShape.copyWith(
        incomingConnectionIds: const [],
        outgoingConnectionIds: const [],
      );
    } catch (_) {
      startShape = FlowchartShapeFactory.createShape(ShapeType.start, const Offset(120, 120));
    }

    // Svuota history (non deve essere possibile fare undo e riapparire tutto)
    _history.clear();

    emit(FlowchartLoaded(
      shapes: [startShape],
      connections: const [],
      selectedShapeId: startShape.id,
    ));
  }

  void _onLinkToExistingEnd(LinkToExistingEnd event, Emitter<FlowchartState> emit) {
    if (state is! FlowchartLoaded) return;
    final current = state as FlowchartLoaded;

    FlowchartShape fromShape;
    FlowchartShape endShape;
    try { fromShape = current.shapes.firstWhere((s) => s.id == event.fromShapeId); } catch (_) { return; }
    // Cerca nodo fine canonico; fallback legacy solo se mai presente
    try { endShape = current.shapes.firstWhere((s) => s.type == 'fine' || s.type == 'end'); } catch (_) { return; }

    // Evita collegamenti duplicati identici
    final already = current.connections.any((c) => c.fromShapeId == fromShape.id && c.toShapeId == endShape.id && c.fromPort == event.fromPort);
    if (already) return;

    final newConn = FlowchartConnection(
      id: const Uuid().v4(),
      fromShapeId: fromShape.id,
      toShapeId: endShape.id,
      fromPort: event.fromPort,
    );

    final validator = FlowchartValidator();
    final validation = validator.validate(current, newConn);
    if (!validation.isValid) {
      emit(FlowchartActionFailure(title: 'Connessione non permessa', message: validation.errorMessage ?? 'Impossibile collegare alla forma Fine.'));
      emit(current); // ripristina
      return;
    }

    final command = AddConnectionCommand(newConn);
    _history.executeCommand(command);
    emit(command.execute(current));
  }
}
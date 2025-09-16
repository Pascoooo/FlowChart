// lib/blocs/flowchart_bloc/history/command_history.dart
import '../commands/flowchart_command.dart';

/// Gestore della cronologia dei comandi per undo/redo
class CommandHistory {
  final List<FlowchartCommand> _undoStack = [];
  final List<FlowchartCommand> _redoStack = [];
  final int maxHistorySize;

  CommandHistory({this.maxHistorySize = 50});

  /// Esegue un comando e lo aggiunge allo stack di undo
  void executeCommand(FlowchartCommand command) {
    _undoStack.add(command);
    _redoStack.clear(); // Pulisce la cronologia redo quando si esegue un nuovo comando

    // Mantiene la dimensione dello stack entro i limiti
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Restituisce true se è possibile fare undo
  bool get canUndo => _undoStack.isNotEmpty;

  /// Restituisce true se è possibile fare redo
  bool get canRedo => _redoStack.isNotEmpty;

  /// Restituisce il comando che verrà annullato (per mostrare nell'UI)
  FlowchartCommand? get nextUndoCommand => _undoStack.isNotEmpty ? _undoStack.last : null;

  /// Restituisce il comando che verrà ripetuto (per mostrare nell'UI)
  FlowchartCommand? get nextRedoCommand => _redoStack.isNotEmpty ? _redoStack.last : null;

  /// Annulla l'ultimo comando
  FlowchartCommand? undo() {
    if (!canUndo) return null;

    final command = _undoStack.removeLast();
    _redoStack.add(command);
    return command;
  }

  /// Ripete l'ultimo comando annullato
  FlowchartCommand? redo() {
    if (!canRedo) return null;

    final command = _redoStack.removeLast();
    _undoStack.add(command);
    return command;
  }

  /// Pulisce tutta la cronologia
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Restituisce informazioni di debug sulla cronologia
  Map<String, dynamic> get debugInfo => {
    'undoStack': _undoStack.map((c) => c.description).toList(),
    'redoStack': _redoStack.map((c) => c.description).toList(),
    'canUndo': canUndo,
    'canRedo': canRedo,
  };
}
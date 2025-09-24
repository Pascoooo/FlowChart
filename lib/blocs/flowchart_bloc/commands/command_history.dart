import 'flowchart_command.dart';

/// Gestore della cronologia dei comandi per undo/redo
class CommandHistory {
  final List<FlowchartCommand> _undoStack = [];
  final List<FlowchartCommand> _redoStack = [];
  final int maxHistorySize;

  CommandHistory({this.maxHistorySize = 50});

  void executeCommand(FlowchartCommand command) {
    _undoStack.add(command);
    _redoStack.clear();

    // Limita la dimensione della cronologia per non usare troppa memoria
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  FlowchartCommand? undo() {
    if (!canUndo) return null;

    final command = _undoStack.removeLast();
    _redoStack.add(command);
    return command;
  }

  FlowchartCommand? redo() {
    if (!canRedo) return null;

    final command = _redoStack.removeLast();
    _undoStack.add(command);
    return command;
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
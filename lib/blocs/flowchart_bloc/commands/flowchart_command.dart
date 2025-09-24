import 'package:flowchart_repository/flowchart_repository.dart';
import '../flowchart_state.dart';

/// Interfaccia base per tutti i comandi eseguibili.
abstract class FlowchartCommand {
  FlowchartLoaded execute(FlowchartLoaded currentState);
  FlowchartLoaded undo(FlowchartLoaded currentState);
  String get description;
}

// --- COMANDI PER I NODI ---

class AddNodeCommand implements FlowchartCommand {
  final FlowNode node;
  AddNodeCommand(this.node);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedNodes = List<FlowNode>.from(currentState.flowchart.nodes)..add(node);
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart, selectedNodeId: node.id);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedNodes = currentState.flowchart.nodes.where((n) => n.id != node.id).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  String get description => 'Aggiungi ${node.kind.name}';
}

class RemoveNodeCommand implements FlowchartCommand {
  final FlowNode node;
  RemoveNodeCommand(this.node);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) => AddNodeCommand(this.node).undo(currentState);
  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) => AddNodeCommand(this.node).execute(currentState);
  @override
  String get description => 'Rimuovi ${node.kind.name}';
}

class MoveNodeCommand implements FlowchartCommand {
  final String nodeId;
  final double newX, newY, oldX, oldY;

  MoveNodeCommand({
    required this.nodeId,
    required this.newX, required this.newY,
    required this.oldX, required this.oldY,
  });

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    // FIX: Aggiunto <FlowNode> per specificare il tipo di ritorno della mappa.
    final updatedNodes = currentState.flowchart.nodes.map<FlowNode>((n) {
      if (n.id == nodeId) {
        return (n as dynamic).copyWith(x: newX, y: newY);
      }
      return n;
    }).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    // FIX: Aggiunto <FlowNode>
    final updatedNodes = currentState.flowchart.nodes.map<FlowNode>((n) {
      if (n.id == nodeId) {
        return (n as dynamic).copyWith(x: oldX, y: oldY);
      }
      return n;
    }).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  String get description => 'Sposta nodo';
}

class UpdateNodeContentCommand implements FlowchartCommand {
  final String nodeId;
  final FlowNode oldNode;
  final Map<String, dynamic> newData;

  UpdateNodeContentCommand({required this.nodeId, required this.oldNode, required this.newData});

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final newNode = (oldNode as dynamic).copyWith(
      text: newData['text'],
      code: newData['code'],
      condition: newData['condition'],
      template: newData['template'],
      variables: newData['variables'], // nuovo campo per OutputNode
      declarations: newData['declarations'], // nuovo campo per InputNode
    );
    // FIX: Aggiunto <FlowNode>
    final updatedNodes = currentState.flowchart.nodes.map<FlowNode>((n) => n.id == nodeId ? newNode : n).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    // FIX: Aggiunto <FlowNode>
    final updatedNodes = currentState.flowchart.nodes.map<FlowNode>((n) => n.id == nodeId ? oldNode : n).toList();
    final newFlowchart = currentState.flowchart.copyWith(nodes: updatedNodes);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  String get description => 'Modifica contenuto nodo';
}


// --- COMANDI PER LE CONNESSIONI ---

class AddEdgeCommand implements FlowchartCommand {
  final FlowchartEdge edge;
  AddEdgeCommand(this.edge);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    final updatedEdges = List<FlowchartEdge>.from(currentState.flowchart.edges)..add(edge);
    final newFlowchart = currentState.flowchart.copyWith(edges: updatedEdges);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    final updatedEdges = currentState.flowchart.edges.where((e) => e != edge).toList();
    final newFlowchart = currentState.flowchart.copyWith(edges: updatedEdges);
    return currentState.copyWith(flowchart: newFlowchart);
  }

  @override
  String get description => 'Aggiungi connessione';
}

class RemoveEdgeCommand implements FlowchartCommand {
  final FlowchartEdge edge;
  RemoveEdgeCommand(this.edge);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) => AddEdgeCommand(edge).undo(currentState);
  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) => AddEdgeCommand(edge).execute(currentState);
  @override
  String get description => 'Rimuovi connessione';
}


// --- COMANDO COMPOSITO ---

class CompositeCommand implements FlowchartCommand {
  final List<FlowchartCommand> commands;
  @override
  final String description;

  CompositeCommand(this.commands, this.description);

  @override
  FlowchartLoaded execute(FlowchartLoaded currentState) {
    return commands.fold(currentState, (state, command) => command.execute(state));
  }

  @override
  FlowchartLoaded undo(FlowchartLoaded currentState) {
    return commands.reversed.fold(currentState, (state, command) => command.undo(state));
  }
}
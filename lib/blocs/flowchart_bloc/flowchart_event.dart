// Questo file non ha richiesto modifiche.

import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';

abstract class FlowchartEvent extends Equatable {
  const FlowchartEvent();
  @override
  List<Object?> get props => [];
}

class LoadFlowchart extends FlowchartEvent {
  final String jsonContent;
  final String fileName;

  const LoadFlowchart({required this.jsonContent, required this.fileName});

  @override
  List<Object?> get props => [jsonContent, fileName];
}

class AddNode extends FlowchartEvent {
  final FlowNodeKind kind;
  final String fromNodeId;
  final String? fromPort;
  final BoxConstraints canvasConstraints;
  final Map<String, dynamic>? initialData;

  const AddNode({
    required this.kind,
    required this.fromNodeId,
    this.fromPort,
    required this.canvasConstraints,
    this.initialData,
  });

  @override
  List<Object?> get props => [kind, fromNodeId, fromPort, canvasConstraints];
}

class RemoveNode extends FlowchartEvent {
  final String nodeId;
  const RemoveNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

class UpdateNodePosition extends FlowchartEvent {
  final String nodeId;
  final double newX;
  final double newY;
  final double oldX;
  final double oldY;

  const UpdateNodePosition({
    required this.nodeId,
    required this.newX,
    required this.newY,
    required this.oldX,
    required this.oldY,
  });
  @override
  List<Object?> get props => [nodeId, newX, newY, oldX, oldY];
}

class UpdateNodeContent extends FlowchartEvent {
  final String nodeId;
  final Map<String, dynamic> newData;

  const UpdateNodeContent({
    required this.nodeId,
    required this.newData,
  });

  @override
  List<Object?> get props => [nodeId, newData];
}

class SelectNode extends FlowchartEvent {
  final String nodeId;
  const SelectNode(this.nodeId);
  @override
  List<Object?> get props => [nodeId];
}

class DeselectNode extends FlowchartEvent {
  const DeselectNode();
}

class LinkToExistingEnd extends FlowchartEvent {
  final String fromNodeId;
  final String? fromPort;

  const LinkToExistingEnd({required this.fromNodeId, this.fromPort});

  @override
  List<Object?> get props => [fromNodeId, fromPort];
}

class Undo extends FlowchartEvent {
  const Undo();
}

class Redo extends FlowchartEvent {
  const Redo();
}

class ResetFlowchart extends FlowchartEvent {
  const ResetFlowchart();
}

class ClearHistory extends FlowchartEvent {
  const ClearHistory();
}
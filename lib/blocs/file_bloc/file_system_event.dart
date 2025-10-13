import 'package:equatable/equatable.dart';
import 'package:flowchart_repository/flowchart_repository.dart';

abstract class FileSystemEvent extends Equatable {
  const FileSystemEvent();
  @override
  List<Object?> get props => [];
}

// --- Eventi CRUD ---

class RefreshFileSystem extends FileSystemEvent {
  final String projectId;
  const RefreshFileSystem({required this.projectId});
  @override
  List<Object?> get props => [projectId];
}

class CreateFile extends FileSystemEvent {
  final String projectId;
  final String fileName;
  final FlowchartSignature? signature; // Firma opzionale per funzioni
  const CreateFile({
    required this.projectId,
    required this.fileName,
    this.signature,
  });
  @override
  List<Object?> get props => [projectId, fileName, signature];
}

class DeleteFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  const DeleteFile({required this.projectId, required this.fileId});
  @override
  List<Object?> get props => [projectId, fileId];
}

class RenameFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String newName;
  const RenameFile(
      {required this.projectId, required this.fileId, required this.newName});
  @override
  List<Object?> get props => [projectId, fileId, newName];
}

class OpenFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  const OpenFile({required this.projectId, required this.fileId});
  @override
  List<Object?> get props => [projectId, fileId];
}


class StartDebugSession extends FileSystemEvent {
  final Flowchart flowchart;
  const StartDebugSession({required this.flowchart});
  @override
  List<Object> get props => [flowchart];
}

class ComputeDebugStep extends FileSystemEvent {
  final int index;
  final List<String> debugPath;
  final Flowchart flowchart;
  const ComputeDebugStep({
    required this.index,
    required this.debugPath,
    required this.flowchart,
  });
  @override
  List<Object> get props => [index, debugPath, flowchart];
}

class EndDebugSession extends FileSystemEvent {
  final String projectId;
  const EndDebugSession({required this.projectId});
  @override
  List<Object> get props => [projectId];
}
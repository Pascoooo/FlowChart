/// Eventi del FileSystem BLoC.
/// Rappresentano tutte le operazioni CRUD sui file (creazione, eliminazione, rinomina, apertura)
/// e azioni di validazione/aggiornamento cache del progetto.
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

class UpdateFileContentInCache extends FileSystemEvent {
  final String fileId;
  final String newContent;

  const UpdateFileContentInCache({required this.fileId, required this.newContent});

  @override
  List<Object> get props => [fileId, newContent];
}

/// Valida (builda) l'intero progetto, verificando correttezza strutturale di tutti i flowchart.
/// Chiamato esplicitamente dall'utente tramite bottone BUILD.
class BuildProject extends FileSystemEvent {
  const BuildProject();
}

/// Invalida il build corrente, richiedendo una nuova validazione.
/// Chiamato automaticamente quando si modificano nodi/edge (operazioni strutturali).
class InvalidateBuild extends FileSystemEvent {
  const InvalidateBuild();
}

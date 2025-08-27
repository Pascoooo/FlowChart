part of 'file_system_bloc.dart';

@immutable
abstract class FileSystemEvent extends Equatable {
  const FileSystemEvent();

  @override
  List<Object> get props => [];
}

/// Evento per creare un nuovo file o una nuova directory.
class CreateNewEntry extends FileSystemEvent {
  final String name;
  final String parentId;
  final bool isDir;

  const CreateNewEntry({
    required this.name,
    required this.parentId,
    required this.isDir,
  });

  @override
  List<Object> get props => [name, parentId, isDir];
}

/// Evento per aprire un file esistente.
class OpenFile extends FileSystemEvent {
  final File file;

  const OpenFile({required this.file});

  @override
  List<Object> get props => [file];
}

/// Evento interno per creare la cartella radice all'avvio.
class CreateNewRoot extends FileSystemEvent {}
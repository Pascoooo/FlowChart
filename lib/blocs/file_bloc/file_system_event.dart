// dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

@immutable
abstract class FileSystemEvent extends Equatable {
  const FileSystemEvent();

  @override
  List<Object?> get props => [];
}

/// Evento per inizializzare il filesystem e caricare i file
class RefreshFileSystem extends FileSystemEvent {
  final String projectId;
  const RefreshFileSystem({required this.projectId});

  @override
  List<Object> get props => [projectId];
}

/// Evento per creare un nuovo file
class CreateNewFile extends FileSystemEvent {
  final String projectId;
  final String fileName;

  const CreateNewFile({required this.projectId, required this.fileName});

  @override
  List<Object> get props => [projectId, fileName];
}

/// Evento per aprire un file
class OpenFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String fileName;

  const OpenFile({required this.projectId, required this.fileId, required this.fileName});

  @override
  List<Object> get props => [projectId, fileId, fileName];
}

/// Evento per eliminare un file
class DeleteFile extends FileSystemEvent {
  final String projectId;
  final String fileId;

  const DeleteFile({required this.projectId, required this.fileId});

  @override
  List<Object> get props => [projectId, fileId];
}

/// Evento per rinominare un file
class RenameFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String newName;

  const RenameFile({required this.projectId, required this.fileId, required this.newName});

  @override
  List<Object> get props => [projectId, fileId, newName];
}

/// Evento per aggiornare il contenuto di un file
class UpdateFileContent extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String newContent;

  const UpdateFileContent({
    required this.projectId,
    required this.fileId,
    required this.newContent,
  });

  @override
  List<Object> get props => [projectId, fileId, newContent];
}
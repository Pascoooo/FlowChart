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
  const RefreshFileSystem();
}

/// Evento per creare un nuovo file
class CreateNewFile extends FileSystemEvent {
  final String fileName;

  const CreateNewFile({required this.fileName});

  @override
  List<Object> get props => [fileName];
}

/// Evento per aprire un file
class OpenFile extends FileSystemEvent {
  final String fileId;
  final String fileName;

  const OpenFile({required this.fileId, required this.fileName});

  @override
  List<Object> get props => [fileId, fileName];
}

/// Evento per eliminare un file
class DeleteFile extends FileSystemEvent {
  final String fileId;

  const DeleteFile({required this.fileId});

  @override
  List<Object> get props => [fileId];
}

/// Evento per rinominare un file
class RenameFile extends FileSystemEvent {
  final String fileId;
  final String newName;

  const RenameFile({required this.fileId, required this.newName});

  @override
  List<Object> get props => [fileId, newName];
}

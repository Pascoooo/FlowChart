import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

@immutable
abstract class FileSystemEvent extends Equatable {
  const FileSystemEvent();
  @override
  List<Object?> get props => [];
}

/// Carica (o ricarica) la lista dei file per un dato progetto.
class RefreshFileSystem extends FileSystemEvent {
  final String projectId;
  const RefreshFileSystem({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

/// Crea un nuovo file all'interno di un progetto.
class CreateNewFile extends FileSystemEvent {
  final String projectId;
  final String fileName;
  const CreateNewFile({required this.projectId, required this.fileName});
  @override
  List<Object> get props => [projectId, fileName];
}

/// Imposta un file come attivo per la visualizzazione e la modifica.
class OpenFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String fileName;
  const OpenFile({required this.projectId, required this.fileId, required this.fileName});
  @override
  List<Object> get props => [projectId, fileId, fileName];
}

/// Elimina un file da un progetto.
class DeleteFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  const DeleteFile({required this.projectId, required this.fileId});
  @override
  List<Object> get props => [projectId, fileId];
}

/// Rinomina un file esistente.
class RenameFile extends FileSystemEvent {
  final String projectId;
  final String fileId;
  final String newName;
  const RenameFile({required this.projectId, required this.fileId, required this.newName});
  @override
  List<Object> get props => [projectId, fileId, newName];
}
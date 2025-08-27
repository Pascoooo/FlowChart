// lib/models/file_system_models.dart
import 'package:equatable/equatable.dart';

/// An abstract class representing a generic entry in the file system.
abstract class FileSystemEntry extends Equatable {
  final String id;
  String name;
  final String parentId;

  FileSystemEntry({
    required this.id,
    required this.name,
    required this.parentId,
  });

  @override
  List<Object> get props => [id, name, parentId];
}

/// Represents a virtual file. For now, its "content" is just a simple ID.
class File extends FileSystemEntry {
  File({
    required super.id,
    required super.name,
    required super.parentId,
  });

  @override
  List<Object> get props => [id, name, parentId];
}

/// Represents a virtual directory.
class Directory extends FileSystemEntry {
  final List<FileSystemEntry> children;

  Directory({
    required super.id,
    required super.name,
    required super.parentId,
    required this.children,
  });

  @override
  List<Object> get props => [id, name, parentId, children];
}

part of 'file_system_bloc.dart';

@immutable
abstract class FileSystemState extends Equatable {
  const FileSystemState();

  @override
  List<Object> get props => [];

  String? get activeFileId => null;

  String? get error => null;
}

/// Stato iniziale del filesystem.
class FileSystemInitial extends FileSystemState {
  const FileSystemInitial();
}

/// Stato che rappresenta il filesystem caricato.
class FileSystemLoaded extends FileSystemState {
  final Directory root;
  final String? _activeFileId;
  @override
  final String? error;

  const FileSystemLoaded({
    required this.root,
    required String? activeFileId,
    this.error,
  }) : _activeFileId = activeFileId;

  @override
  String? get activeFileId => _activeFileId;

  /// Crea una copia dello stato con nuovi valori.
  FileSystemLoaded copyWith({
    Directory? root,
    String? activeFileId,
    String? error,
  }) {
    return FileSystemLoaded(
      root: root ?? this.root,
      activeFileId: activeFileId ?? _activeFileId,
      error: error,
    );
  }

  @override
  List<Object> get props => [root, _activeFileId ?? '', error ?? ''];
}

/// Stato che rappresenta un errore del filesystem.
class FileSystemError extends FileSystemState {
  final String message;

  const FileSystemError({required this.message});

  @override
  List<Object> get props => [message];
}
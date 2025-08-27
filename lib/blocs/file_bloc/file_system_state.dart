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
  final String? _error;

  const FileSystemLoaded({
    required this.root,
    required String? activeFileId,
    String? error,
  }) : _activeFileId = activeFileId, _error = error;

  @override
  String? get activeFileId => _activeFileId;

  @override
  String? get error => _error;

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
  List<Object> get props => [root, _activeFileId ?? '', _error ?? ''];
}

/// Stato che rappresenta un errore del filesystem.
class FileSystemError extends FileSystemState {
  final String message;

  const FileSystemError({required this.message});

  @override
  List<Object> get props => [message];
}
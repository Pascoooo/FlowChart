import 'package:equatable/equatable.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flutter/material.dart';

@immutable
abstract class FileSystemState extends Equatable {
  const FileSystemState();
  @override
  List<Object?> get props => [];
}

class FileSystemInitial extends FileSystemState {
  const FileSystemInitial();
}

class FileSystemError extends FileSystemState {
  final String message;
  const FileSystemError({required this.message});
  @override
  List<Object> get props => [message];
}

/// Stato di caricamento iniziale, quando la lista file non è ancora disponibile.
class FileSystemLoading extends FileSystemState {
  const FileSystemLoading();
}

/// Stato che rappresenta il filesystem caricato.
class FileSystemLoaded extends FileSystemState {
  final List<MyFile> files;
  final String? activeFileId;
  final String? error;
  final bool isLoading;

  const FileSystemLoaded({
    required this.files,
    this.activeFileId,
    this.error,
    this.isLoading = false,
  });

  FileSystemLoaded copyWith({
    List<MyFile>? files,
    String? activeFileId,
    bool clearActiveFile = false,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return FileSystemLoaded(
      files: files ?? this.files,
      activeFileId: clearActiveFile ? null : (activeFileId ?? this.activeFileId),
      error: clearError ? null : error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [files, activeFileId, error, isLoading];
}
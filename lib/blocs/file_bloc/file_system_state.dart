import 'package:equatable/equatable.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flutter/material.dart';

@immutable
abstract class FileSystemState extends Equatable {
  const FileSystemState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale del filesystem
class FileSystemInitial extends FileSystemState {
  const FileSystemInitial();
}

/// Stato che rappresenta un errore del filesystem
class FileSystemError extends FileSystemState {
  final String message;

  const FileSystemError({required this.message});

  @override
  List<Object> get props => [message];
}

/// Stato di caricamento
class FileSystemLoading extends FileSystemState {
  const FileSystemLoading();
}

/// Stato che rappresenta il filesystem caricato con la lista dei file
class FileSystemLoaded extends FileSystemState {
  final List<MyFile> files;
  final String? activeFileId;
  final String? error;
  final String? successMessage;

  const FileSystemLoaded({
    required this.files,
    this.activeFileId,
    this.error,
    this.successMessage,
  });

  FileSystemLoaded copyWith({
    List<MyFile>? files,
    String? activeFileId,
    String? error,
    String? successMessage,
  }) {
    return FileSystemLoaded(
      files: files ?? this.files,
      activeFileId: activeFileId ?? this.activeFileId,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
    files,
    activeFileId,
    error,
    successMessage,
  ];
}

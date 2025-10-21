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

class FileSystemLoading extends FileSystemState {
  const FileSystemLoading();
}

class FileSystemLoaded extends FileSystemState {
  final List<MyFile> files;
  final String? activeFileId;
  final String? error;
  final bool isLoading;
  final String? executionCode; // Proprietà per contenere il codice C generato
  final bool isProjectValid; // NUOVO: Stato di validazione del progetto

  const FileSystemLoaded({
    required this.files,
    this.activeFileId,
    this.error,
    this.isLoading = false,
    this.executionCode,
    this.isProjectValid = false, // Default a non valido
  });

  FileSystemLoaded copyWith({
    List<MyFile>? files,
    String? activeFileId,
    bool clearActiveFile = false,
    String? error,
    bool clearError = false,
    bool? isLoading,
    String? executionCode,
    bool clearExecutionCode = false, // Flag per pulire il codice
    bool? isProjectValid, // NUOVO
  }) {
    return FileSystemLoaded(
      files: files ?? this.files,
      activeFileId: clearActiveFile ? null : (activeFileId ?? this.activeFileId),
      error: clearError ? null : error,
      isLoading: isLoading ?? this.isLoading,
      executionCode: clearExecutionCode ? null : (executionCode ?? this.executionCode),
      isProjectValid: isProjectValid ?? this.isProjectValid, // NUOVO
    );
  }

  @override
  List<Object?> get props => [files, activeFileId, error, isLoading, executionCode, isProjectValid];
}
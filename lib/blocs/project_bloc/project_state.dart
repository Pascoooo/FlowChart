/// Stati del Project BLoC.
/// Rappresenta i diversi stati del progetto: iniziale, caricamento, errore, lista progetti caricata,
/// modifiche non salvate trovate e workspace statico caricato (read-only).
import 'package:equatable/equatable.dart';
import 'package:file_repository/file_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flutter/material.dart';

@immutable
abstract class ProjectState extends Equatable {
  const ProjectState();
  @override
  List<Object?> get props => [];
}

class ProjectInitial extends ProjectState {
  const ProjectInitial();
}

class ProjectLoading extends ProjectState {
  final String? message;
  const ProjectLoading({this.message});
  @override
  List<Object?> get props => [message];
}

class ProjectError extends ProjectState {
  final String message;
  const ProjectError({required this.message});
  @override
  List<Object> get props => [message];
}

class UnsavedChangesFound extends ProjectState {
  final String projectId;
  final String projectName;
  final List<UnsavedFileChange> changedFiles;

  const UnsavedChangesFound({
    required this.projectId,
    required this.projectName,
    required this.changedFiles,
  });

  @override
  List<Object> get props => [projectId, projectName, changedFiles];
}

class ProjectsLoaded extends ProjectState {
  final List<MyProject> projects;
  final MyProject? selectedProject;
  final bool isReadOnlyView;
  final String? error;

  const ProjectsLoaded({
    required this.projects,
    this.selectedProject,
    this.isReadOnlyView = false, // Default a non read-only
    this.error,
  });

  /// Crea una copia dello stato con modifiche selettive.
  /// clearSelectedProject e clearError consentono di pulire esplicitamente i campi.
  ProjectsLoaded copyWith({
    List<MyProject>? projects,
    MyProject? selectedProject,
    bool? isReadOnlyView,
    bool clearSelectedProject = false,
    String? error,
    bool clearError = false,
  }) {
    return ProjectsLoaded(
      projects: projects ?? this.projects,
      selectedProject: clearSelectedProject ? null : (selectedProject ?? this.selectedProject),
      isReadOnlyView: isReadOnlyView ?? this.isReadOnlyView, // <-- AGGIUNTO
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [projects, selectedProject, isReadOnlyView, error];
}

// Aggiungi questa nuova classe alla fine del file

class StaticWorkspaceLoaded extends ProjectState {
  final MyProject project;
  final List<MyFile> files;

  const StaticWorkspaceLoaded({
    required this.project,
    required this.files,
  });

  @override
  List<Object> get props => [project, files];
}
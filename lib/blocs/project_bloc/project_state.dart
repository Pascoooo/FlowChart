import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';

@immutable
abstract class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale del progetto
class ProjectInitial extends ProjectState {
  const ProjectInitial();
}

/// Stato che indica che un'operazione è in corso
class ProjectLoading extends ProjectState {
  const ProjectLoading();
}

/// Stato che indica un errore bloccante.
class ProjectError extends ProjectState {
  final String message;
  const ProjectError({required this.message});
  @override
  List<Object> get props => [message];
}

/// Stato che indica la presenza di una sessione non salvata, per attivare il dialogo.
class UnsavedChangesFound extends ProjectState {
  final String projectId;
  final String projectName;
  const UnsavedChangesFound({required this.projectId, required this.projectName});
  @override
  List<Object> get props => [projectId, projectName];
}

/// Stato principale con i dati dei progetti caricati.
class ProjectsLoaded extends ProjectState {
  final List<MyProject> projects;
  final MyProject? selectedProject;
  final String? error;

  const ProjectsLoaded({
    required this.projects,
    this.selectedProject,
    this.error,
  });

  ProjectsLoaded copyWith({
    List<MyProject>? projects,
    MyProject? selectedProject,
    bool clearSelectedProject = false,
    String? error,
    bool clearError = false,
  }) {
    return ProjectsLoaded(
      projects: projects ?? this.projects,
      selectedProject: clearSelectedProject ? null : (selectedProject ?? this.selectedProject),
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [projects, selectedProject, error];
}
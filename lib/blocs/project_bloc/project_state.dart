// lib/blocs/project_bloc/project_state.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';

@immutable
abstract class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

/// Initial state of the project
class ProjectInitial extends ProjectState {
  const ProjectInitial();
}

/// Loading state for initial project load
class ProjectLoading extends ProjectState {
  const ProjectLoading();
}

/// State indicating an operation is in progress (create, rename, delete)
class ProjectOperationInProgress extends ProjectState {
  const ProjectOperationInProgress();
}

/// State indicating an operation completed successfully
class ProjectOperationSuccess extends ProjectState {
  final String? message;

  const ProjectOperationSuccess({this.message});

  @override
  List<Object?> get props => [message];
}

/// Error state for any project operation
class ProjectError extends ProjectState {
  final String message;

  const ProjectError({required this.message});

  @override
  List<Object> get props => [message];
}

/// Main state containing the list of projects
class ProjectsLoaded extends ProjectState {
  final List<MyProject> projects;
  final MyProject? selectedProject;

  const ProjectsLoaded({
    required this.projects,
    this.selectedProject,
  });

  ProjectsLoaded copyWith({
    List<MyProject>? projects,
    MyProject? selectedProject,
    bool clearSelectedProject = false,
  }) {
    return ProjectsLoaded(
      projects: projects ?? this.projects,
      selectedProject: clearSelectedProject ? null : (selectedProject ?? this.selectedProject),
    );
  }

  @override
  List<Object?> get props => [projects, selectedProject];
}
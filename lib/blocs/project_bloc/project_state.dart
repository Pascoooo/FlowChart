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

/// Stato che rappresenta un errore durante un'operazione
class ProjectError extends ProjectState {
  final String message;

  const ProjectError({required this.message});

  @override
  List<Object> get props => [message];
}

/// Stato di successo
class ProjectSuccess extends ProjectState {
  final String message;

  const ProjectSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

class ProjectsLoaded extends ProjectState {
  final List<MyProject> projects;
  final MyProject? selectedProject;
  final String? error;
  final String? successMessage;

  const ProjectsLoaded({
    required this.projects,
    this.selectedProject,
    this.error,
    this.successMessage,
  });

  ProjectsLoaded copyWith({
    List<MyProject>? projects,
    MyProject? selectedProject,
    String? error,
    String? successMessage,
  }) {
    return ProjectsLoaded(
      projects: projects ?? this.projects,
      selectedProject: selectedProject ?? this.selectedProject,
      error: error,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
    projects,
    selectedProject,
    error,
    successMessage,
  ];
}
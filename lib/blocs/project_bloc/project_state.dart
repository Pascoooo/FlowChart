import 'package:equatable/equatable.dart';
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
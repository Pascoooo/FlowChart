import 'package:equatable/equatable.dart';
import 'package:project_repository/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

class CreateProject extends ProjectEvent {
  final String projectName;
  const CreateProject({required this.projectName});
  @override
  List<Object> get props => [projectName];
}

class DeleteProject extends ProjectEvent {
  final String projectId;
  const DeleteProject({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

class RenameProject extends ProjectEvent {
  final String projectId;
  final String newName;
  const RenameProject({required this.projectId, required this.newName});
  @override
  List<Object> get props => [projectId, newName];
}

class LoadProjects extends ProjectEvent {
  const LoadProjects();
}

class SelectProject extends ProjectEvent {
  final MyProject project;
  const SelectProject({required this.project});
  @override
  List<Object> get props => [project];
}

class DeselectProject extends ProjectEvent {
  const DeselectProject();
}

class ProjectsUpdated extends ProjectEvent {
  final List<MyProject> projects;
  const ProjectsUpdated(this.projects);

  @override
  List<Object> get props => [projects];
}
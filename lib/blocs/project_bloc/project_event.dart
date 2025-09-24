import 'package:equatable/equatable.dart';
import 'package:project_repository/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

// --- Eventi Esistenti ---
class CheckForUnsavedSessions extends ProjectEvent {
  const CheckForUnsavedSessions();
}

class RecoverSession extends ProjectEvent {
  final String projectId;
  const RecoverSession({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

class DiscardSession extends ProjectEvent {
  final String projectId;
  const DiscardSession({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

class LoadProjects extends ProjectEvent {
  const LoadProjects();
}

class StartSessionAndSelectProject extends ProjectEvent {
  final MyProject project;
  const StartSessionAndSelectProject({required this.project});
  @override
  List<Object> get props => [project];
}

class LeaveProject extends ProjectEvent {
  const LeaveProject();
}

class ProjectsUpdated extends ProjectEvent {
  final List<MyProject> projects;
  const ProjectsUpdated(this.projects);
  @override
  List<Object> get props => [projects];
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

class RecoverSingleFile extends ProjectEvent {
  final String projectId;
  final String fileId;
  final String rtdbContent;
  const RecoverSingleFile({required this.projectId, required this.fileId, required this.rtdbContent});
  @override
  List<Object> get props => [projectId, fileId, rtdbContent];
}

class DiscardSingleFileChange extends ProjectEvent {
  final String projectId;
  final String fileId;
  const DiscardSingleFileChange({required this.projectId, required this.fileId});
  @override
  List<Object> get props => [projectId, fileId];
}

/// Aggiorna la visibilità (pubblica/privata) di un progetto.
class UpdateProjectVisibility extends ProjectEvent {
  final String projectId;
  final bool isPublic;
  const UpdateProjectVisibility({required this.projectId, required this.isPublic});
  @override
  List<Object> get props => [projectId, isPublic];
}



class LoadStaticWorkspace extends ProjectEvent {
  final String projectId;
  const LoadStaticWorkspace({required this.projectId});
  @override
  List<Object> get props => [projectId];
}
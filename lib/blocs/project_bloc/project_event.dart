import 'package:equatable/equatable.dart';
import 'package:project_repository/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

// --- Eventi del Ciclo di Vita della Sessione ---
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

// --- Eventi di Notifica dallo Stream ---
class ProjectsUpdated extends ProjectEvent {
  final List<MyProject> projects;
  const ProjectsUpdated(this.projects);
  @override
  List<Object> get props => [projects];
}


/// Crea un nuovo progetto.
class CreateProject extends ProjectEvent {
  final String projectName;
  const CreateProject({required this.projectName});
  @override
  List<Object> get props => [projectName];
}

/// Elimina un progetto.
class DeleteProject extends ProjectEvent {
  final String projectId;
  const DeleteProject({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

/// Rinomina un progetto.
class RenameProject extends ProjectEvent {
  final String projectId;
  final String newName;
  const RenameProject({required this.projectId, required this.newName});
  @override
  List<Object> get props => [projectId, newName];
}

// --- Eventi di Recupero Manuale ---

/// Recupera le modifiche per un singolo file.
class RecoverSingleFile extends ProjectEvent {
  final String projectId;
  final String fileId;
  final String rtdbContent;

  const RecoverSingleFile({
    required this.projectId,
    required this.fileId,
    required this.rtdbContent,
  });

  @override
  List<Object> get props => [projectId, fileId, rtdbContent];
}

/// Scarta le modifiche per un singolo file.
class DiscardSingleFileChange extends ProjectEvent {
  final String projectId;
  final String fileId;

  const DiscardSingleFileChange({required this.projectId, required this.fileId});

  @override
  List<Object> get props => [projectId, fileId];
}
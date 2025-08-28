// lib/blocs/project_bloc/project_event.dart (Updated)
import 'package:equatable/equatable.dart';
import 'package:project_repository/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();

  @override
  List<Object?> get props => [];
}

/// Evento per creare un nuovo progetto
class CreateProject extends ProjectEvent {
  final String projectName;

  const CreateProject({required this.projectName});

  @override
  List<Object> get props => [projectName];
}

/// Evento per eliminare un progetto
class DeleteProject extends ProjectEvent {
  final String projectId;

  const DeleteProject({required this.projectId});

  @override
  List<Object> get props => [projectId];
}

/// Evento per rinominare un progetto
class RenameProject extends ProjectEvent {
  final String projectId;
  final String newName;

  const RenameProject({required this.projectId, required this.newName});

  @override
  List<Object> get props => [projectId, newName];
}

/// Evento per caricare la lista di tutti i progetti
class LoadProjects extends ProjectEvent {
  const LoadProjects();
}

/// Evento per selezionare un progetto
class SelectProject extends ProjectEvent {
  final MyProject project;

  const SelectProject({required this.project});

  @override
  List<Object> get props => [project];
}

/// Evento per deselezionare il progetto corrente e tornare alla vista progetti
class DeselectProject extends ProjectEvent {
  const DeselectProject();
}
import 'package:equatable/equatable.dart';
import 'package:project_repository/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();
  @override
  List<Object?> get props => [];
}

/// Avvia il controllo per sessioni non salvate all'avvio dell'app.
class CheckForUnsavedSessions extends ProjectEvent {
  const CheckForUnsavedSessions();
}

/// L'utente ha scelto di recuperare la sessione da RTDB.
class RecoverSession extends ProjectEvent {
  final String projectId;
  const RecoverSession({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

/// L'utente ha scelto di scartare la sessione da RTDB.
class DiscardSession extends ProjectEvent {
  final String projectId;
  const DiscardSession({required this.projectId});
  @override
  List<Object> get props => [projectId];
}

/// Avvia il caricamento della lista dei progetti da Firestore.
class LoadProjects extends ProjectEvent {
  const LoadProjects();
}

/// Prepara la sessione in RTDB e poi seleziona un progetto per la navigazione.
class StartSessionAndSelectProject extends ProjectEvent {
  final MyProject project;
  const StartSessionAndSelectProject({required this.project});
  @override
  List<Object> get props => [project];
}

/// Salva la sessione ed esce dal workspace.
class LeaveProject extends ProjectEvent {
  const LeaveProject();
}

/// Notifica al BLoC che lo stream di Firestore ha emesso nuovi dati.
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
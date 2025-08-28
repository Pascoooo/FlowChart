import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  // Aggiungi il repository come dipendenza
  final FirebaseProjectRepo projectRepository;

  ProjectBloc({required this.projectRepository})
      : super(const ProjectInitial()) {
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
    on<LoadProjects>(_onLoadProjects);
  }

  // Nuovo: Metodo per caricare i progetti all'avvio
  Future<void> _onLoadProjects(
      LoadProjects event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      final projects = await projectRepository.getProjects();
      emit(ProjectsLoaded(projects: projects));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nel caricamento dei progetti', emit);
    }
  }

  /// Gestisce la creazione di un nuovo progetto
  Future<void> _onCreateProject(
      CreateProject event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      await projectRepository.createProject(name: event.projectName);
      final projects = await projectRepository.getProjects(); // Ricarica i progetti
      emit(ProjectsLoaded(projects: projects));
      emit(const ProjectSuccess(message: 'Progetto creato con successo.'));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella creazione del progetto', emit);
    }
  }

  /// Gestisce l'eliminazione di un progetto
  Future<void> _onDeleteProject(
      DeleteProject event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      await projectRepository.deleteProject(projectId: event.projectId);
      final projects = await projectRepository.getProjects(); // Ricarica i progetti
      emit(ProjectsLoaded(projects: projects));
      emit(const ProjectSuccess(message: 'Progetto eliminato.'));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nell\'eliminazione del progetto', emit);
    }
  }

  /// Gestisce la ridenominazione di un progetto
  Future<void> _onRenameProject(
      RenameProject event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      if (event.newName.trim().isEmpty) {
        throw Exception('Il nuovo nome non può essere vuoto.');
      }
      await projectRepository.renameProject(
          projectId: event.projectId, newName: event.newName.trim());
      final projects = await projectRepository.getProjects(); // Ricarica i progetti
      emit(ProjectsLoaded(projects: projects));
      emit(const ProjectSuccess(message: 'Progetto rinominato con successo.'));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella ridenominazione', emit);
    }
  }


  /// Funzione helper per la gestione degli errori
  void _handleError(
      Object e, StackTrace stackTrace, String prefix, Emitter<ProjectState> emit) {
    if (kDebugMode) {
      debugPrint('$prefix: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
    emit(ProjectError(message: '$prefix: $e'));
  }
}
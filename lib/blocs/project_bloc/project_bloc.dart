// lib/blocs/project_bloc/project_bloc.dart (Updated)
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final FirebaseProjectRepo projectRepository;

  ProjectBloc({required this.projectRepository})
      : super(const ProjectInitial()) {
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
    on<LoadProjects>(_onLoadProjects);
    on<SelectProject>(_onSelectProject);
    on<DeselectProject>(_onDeselectProject);
  }

  Future<void> _onLoadProjects(
      LoadProjects event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      final projects = await projectRepository.getProjects();
      emit(ProjectsLoaded(projects: projects, selectedProject: null));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nel caricamento dei progetti', emit);
    }
  }

  void _onSelectProject(
      SelectProject event,
      Emitter<ProjectState> emit,
      ) {
    if (state is ProjectsLoaded) {
      final currentState = state as ProjectsLoaded;
      emit(currentState.copyWith(selectedProject: event.project));
    }
  }

  void _onDeselectProject(
      DeselectProject event,
      Emitter<ProjectState> emit,
      ) {
    if (state is ProjectsLoaded) {
      final currentState = state as ProjectsLoaded;
      emit(currentState.copyWith(selectedProject: null));
    }
  }

  Future<void> _onCreateProject(
      CreateProject event,
      Emitter<ProjectState> emit,
      ) async {
    // Mantieni lo stato corrente durante la creazione
    final currentState = state;

    emit(const ProjectLoading());
    try {
      await projectRepository.createProject(name: event.projectName);
      final projects = await projectRepository.getProjects();

      // Trova il progetto appena creato e selezionalo automaticamente
      final newProject = projects.firstWhere(
            (p) => p.name == event.projectName,
        orElse: () => projects.last,
      );

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: newProject, // Seleziona automaticamente il nuovo progetto
        successMessage: 'Progetto "${event.projectName}" creato con successo.',
      ));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella creazione del progetto', emit);

      // Ripristina lo stato precedente in caso di errore
      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteProject(
      DeleteProject event,
      Emitter<ProjectState> emit,
      ) async {
    final currentState = state;

    emit(const ProjectLoading());
    try {
      await projectRepository.deleteProject(projectId: event.projectId);
      final projects = await projectRepository.getProjects();

      // Se il progetto eliminato era selezionato, deselezionalo
      MyProject? selectedProject;
      if (currentState is ProjectsLoaded &&
          currentState.selectedProject?.projectId != event.projectId) {
        selectedProject = currentState.selectedProject;
      }

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: selectedProject,
        successMessage: 'Progetto eliminato con successo.',
      ));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nell\'eliminazione del progetto', emit);

      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onRenameProject(
      RenameProject event,
      Emitter<ProjectState> emit,
      ) async {
    final currentState = state;

    emit(const ProjectLoading());
    try {
      if (event.newName.trim().isEmpty) {
        throw Exception('Il nuovo nome non può essere vuoto.');
      }

      await projectRepository.renameProject(
          projectId: event.projectId, newName: event.newName.trim());
      final projects = await projectRepository.getProjects();

      // Mantieni la selezione del progetto rinominato
      MyProject? selectedProject;
      if (currentState is ProjectsLoaded && currentState.selectedProject != null) {
        if (currentState.selectedProject!.projectId == event.projectId) {
          selectedProject = projects.firstWhere(
                (p) => p.projectId == event.projectId,
            orElse: () => currentState.selectedProject!,
          );
        } else {
          selectedProject = currentState.selectedProject;
        }
      }

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: selectedProject,
        successMessage: 'Progetto rinominato con successo.',
      ));
    } catch (e, stackTrace) {
      _handleError(e, stackTrace, 'Errore nella ridenominazione', emit);

      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }

  void _handleError(
      Object e, StackTrace stackTrace, String prefix, Emitter<ProjectState> emit) {
    if (kDebugMode) {
      debugPrint('$prefix: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
    emit(ProjectError(message: '$prefix: $e'));
  }
}
// lib/blocs/project_bloc/project_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final FirebaseProjectRepo projectRepository;

  ProjectBloc({required this.projectRepository})
      : super(const ProjectInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
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
    } catch (e) {
      emit(ProjectError(message: 'Errore nel caricamento dei progetti: ${e.toString()}'));
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
      emit(currentState.copyWith(clearSelectedProject: true));
    }
  }

  Future<void> _onCreateProject(
      CreateProject event,
      Emitter<ProjectState> emit,
      ) async {
    final currentState = state;

    // Validate project name
    final trimmedName = event.projectName.trim();
    if (trimmedName.isEmpty) {
      emit(const ProjectError(message: 'Il nome del progetto non può essere vuoto.'));
      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
      return;
    }

    // Check for duplicate names (case-insensitive)
    if (currentState is ProjectsLoaded) {
      final isDuplicate = currentState.projects.any(
            (p) => p.name.toLowerCase() == trimmedName.toLowerCase(),
      );

      if (isDuplicate) {
        emit(const ProjectError(message: 'Un progetto con questo nome esiste già.'));
        emit(currentState);
        return;
      }
    }

    emit(const ProjectOperationInProgress());

    try {
      // Create the project
      await projectRepository.createProject(name: trimmedName);

      // Get the created project to obtain its ID
      final projects = await projectRepository.getProjects();
      final newProject = projects.firstWhere(
            (p) => p.name == trimmedName,
        orElse: () => projects.last,
      );

      // Create the initial "main" file for the project
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: '{}', // Empty JSON content for flowchart
      );

      emit(ProjectOperationSuccess(message: 'Progetto creato con successo'));

      // Reload projects and select the new one
      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: newProject,
      ));
    } catch (e) {
      emit(ProjectError(message: 'Errore nella creazione del progetto: ${e.toString()}'));

      if (currentState is ProjectsLoaded) {
        emit(currentState);
      } else {
        emit(const ProjectInitial());
      }
    }
  }

  Future<void> _onDeleteProject(
      DeleteProject event,
      Emitter<ProjectState> emit,
      ) async {
    final currentState = state;

    emit(const ProjectOperationInProgress());

    try {
      await projectRepository.deleteProject(projectId: event.projectId);
      final projects = await projectRepository.getProjects();

      // If the deleted project was selected, deselect it
      MyProject? selectedProject;
      if (currentState is ProjectsLoaded &&
          currentState.selectedProject?.projectId != event.projectId) {
        selectedProject = currentState.selectedProject;
      }

      emit(const ProjectOperationSuccess(message: 'Progetto eliminato con successo'));

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: selectedProject,
      ));
    } catch (e) {
      emit(ProjectError(message: 'Errore nell\'eliminazione del progetto: ${e.toString()}'));

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

    // Validate new name
    final trimmedName = event.newName.trim();
    if (trimmedName.isEmpty) {
      emit(const ProjectError(message: 'Il nuovo nome non può essere vuoto.'));
      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
      return;
    }

    // Check for duplicate names (case-insensitive), excluding current project
    if (currentState is ProjectsLoaded) {
      final isDuplicate = currentState.projects.any(
            (p) => p.projectId != event.projectId &&
            p.name.toLowerCase() == trimmedName.toLowerCase(),
      );

      if (isDuplicate) {
        emit(const ProjectError(message: 'Un progetto con questo nome esiste già.'));
        emit(currentState);
        return;
      }
    }

    emit(const ProjectOperationInProgress());

    try {
      await projectRepository.renameProject(
        projectId: event.projectId,
        newName: trimmedName,
      );
      final projects = await projectRepository.getProjects();

      // Maintain selection of the renamed project
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

      emit(const ProjectOperationSuccess(message: 'Progetto rinominato con successo'));

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: selectedProject,
      ));
    } catch (e) {
      emit(ProjectError(message: 'Errore nella rinominazione del progetto: ${e.toString()}'));

      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }
}
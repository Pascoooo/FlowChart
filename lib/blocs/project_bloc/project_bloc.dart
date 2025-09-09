import 'package:bloc/bloc.dart';
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
    } catch (e) {
      emit(const ProjectError(message: 'Errore nel caricamento del progetto.'));
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
    emit(const ProjectLoading());
    try {
      if (event.projectName.trim().isEmpty) {
        throw Exception('Il nome del progetto non può essere vuoto.');
      }

      // Controllo unicità nome
      final existingProjects = await projectRepository.getProjects();
      if (existingProjects.any((p) => p.name == event.projectName.trim())) {
        throw Exception('Esiste già un progetto con questo nome.');
      }

      await projectRepository.createProject(name: event.projectName.trim());
      final projects = await projectRepository.getProjects();

      // Crea il file di default "main"
      final newProject = projects.firstWhere((p) => p.name == event.projectName.trim());
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: '',
      );

      emit(ProjectsLoaded(
        projects: projects,
        selectedProject: newProject,
      ));
    } catch (e) {
      emit(ProjectError(message: e.toString()));
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
      ));
    } catch (e) {
      emit(const ProjectError(message: 'Errore nella cancellazione del progetto.'));

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

      // Controllo unicità nome
      final existingProjects = await projectRepository.getProjects();
      if (existingProjects.any(
            (p) => p.name == event.newName.trim() && p.projectId != event.projectId,
      )) {
        throw Exception('Esiste già un progetto con questo nome.');
      }

      await projectRepository.renameProject(
        projectId: event.projectId,
        newName: event.newName.trim(),
      );

      final projects = await projectRepository.getProjects();

      // Mantieni la selezione
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
      ));
    } catch (e) {
      emit(ProjectError(message: e.toString()));
      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }


}
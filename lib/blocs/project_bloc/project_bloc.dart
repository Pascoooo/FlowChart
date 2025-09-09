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

  // MODIFICA: La funzione di caricamento ora ordina i progetti.
  Future<void> _onLoadProjects(
      LoadProjects event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      final projects = await projectRepository.getProjects();
      // Ordina i progetti per data di aggiornamento (dal più recente al meno recente).
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(ProjectsLoaded(projects: projects, selectedProject: null));
    } catch (e) {
      emit(const ProjectError(message: 'Errore nel caricamento del progetto.'));
    }
  }


  // MODIFICA: La selezione di un progetto ora è asincrona per aggiornare il timestamp.
  Future<void> _onSelectProject(
      SelectProject event,
      Emitter<ProjectState> emit,
      ) async {
    if (state is ProjectsLoaded) {
      emit(const ProjectLoading());
      try {
        // 1. Aggiorna il timestamp del progetto selezionato.
        await projectRepository.updateProjectTimestamp(projectId: event.project.projectId);

        // 2. Ricarica e ordina la lista dei progetti.
        final projects = await projectRepository.getProjects();
        projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        // 3. Emetti il nuovo stato con la lista ordinata e il progetto selezionato.
        emit(ProjectsLoaded(
            projects: projects,
            selectedProject: event.project
        ));

      } catch (e) {
        emit(const ProjectError(message: 'Errore durante la selezione del progetto.'));
        final currentState = state as ProjectsLoaded;
        emit(currentState); // Ritorna allo stato precedente in caso di errore
      }
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

      // MODIFICA: Ordina la lista dopo la creazione.
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

      // MODIFICA: Ordina la lista dopo l'eliminazione.
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

      // MODIFICA: Non è necessario aggiornare il timestamp qui, ma ordiniamo la lista
      // per coerenza, anche se l'ordine non dovrebbe cambiare.
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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
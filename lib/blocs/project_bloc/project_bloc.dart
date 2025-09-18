import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

/// Gestisce lo stato e la logica di business per i progetti.
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepo projectRepository;
  StreamSubscription? _projectsSubscription;

  ProjectBloc({required this.projectRepository}) : super(const ProjectInitial()) {
    on<CheckForUnsavedSessions>(_onCheckForUnsavedSessions);
    on<RecoverSession>(_onRecoverSession);
    on<DiscardSession>(_onDiscardSession);
    on<LoadProjects>(_onLoadProjects);
    on<ProjectsUpdated>(_onProjectsUpdated);
    on<StartSessionAndSelectProject>(_onStartSessionAndSelectProject);
    on<LeaveProject>(_onLeaveProject);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
  }

  /// Controlla se ci sono sessioni non salvate all'avvio.
  Future<void> _onCheckForUnsavedSessions(CheckForUnsavedSessions event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading());
    try {
      final pendingSession = await projectRepository.checkForPendingSessions();
      if (pendingSession != null) {
        emit(UnsavedChangesFound(
            projectId: pendingSession.projectId,
            projectName: pendingSession.projectName));
      } else {
        add(const LoadProjects());
      }
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante la verifica dei dati.'));
    }
  }

  /// Recupera una sessione non salvata.
  Future<void> _onRecoverSession(RecoverSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading());
    try {
      await projectRepository.recoverSession(event.projectId);
      add(const LoadProjects());
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante il recupero.'));
    }
  }

  /// Scarta una sessione non salvata.
  Future<void> _onDiscardSession(DiscardSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading());
    try {
      await projectRepository.discardSession(event.projectId);
      add(const LoadProjects());
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante l\'eliminazione.'));
    }
  }

  /// Carica la lista dei progetti.
  Future<void> _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) async {
    await _projectsSubscription?.cancel();
    emit(const ProjectLoading());
    _projectsSubscription = projectRepository.projects().listen(
          (projects) => add(ProjectsUpdated(projects)),
      onError: (e) => emit(const ProjectError(message: 'Errore di connessione.')),
    );
  }

  /// Aggiorna lo stato con la nuova lista di progetti ricevuta dallo stream.
  void _onProjectsUpdated(ProjectsUpdated event, Emitter<ProjectState> emit) {
    emit(ProjectsLoaded(projects: event.projects));
  }

  /// Prepara la sessione e seleziona un progetto.
  Future<void> _onStartSessionAndSelectProject(StartSessionAndSelectProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    emit(const ProjectLoading());
    try {
      await projectRepository.startWorkspaceSession(event.project);
      emit(currentState.copyWith(selectedProject: event.project));
    } catch (e) {
      emit(currentState.copyWith(error: "Impossibile avviare la sessione."));
    }
  }

  /// Salva la sessione ed esce dal workspace.
  Future<void> _onLeaveProject(LeaveProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    final projectToSave = currentState.selectedProject;
    if (projectToSave == null) return;

    emit(const ProjectLoading());
    try {
      await projectRepository.endWorkspaceSession(projectToSave.projectId);
      emit(currentState.copyWith(clearSelectedProject: true));
    } catch (e) {
      emit(currentState.copyWith(error: "Errore durante il salvataggio."));
    }
  }

  /// Crea un nuovo progetto e un file 'main' di default.
  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    try {
      final newProject = await projectRepository.createProject(name: event.projectName.trim());
      await projectRepository.addFileToProject(
          projectId: newProject.projectId,
          fileName: 'main',
          content: ''
      );
      add(StartSessionAndSelectProject(project: newProject));
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore nella creazione del progetto.'));
    }
  }

  /// Gestisce l'eliminazione di un progetto.
  Future<void> _onDeleteProject(DeleteProject event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.deleteProject(projectId: event.projectId);
    } catch (e) {
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: 'Errore durante l\'eliminazione.'));
      }
    }
  }

  /// Gestisce la rinomina di un progetto.
  Future<void> _onRenameProject(RenameProject event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.renameProject(
          projectId: event.projectId, newName: event.newName.trim());
    } catch (e) {
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: 'Errore durante la rinomina.'));
      }
    }
  }

  @override
  Future<void> close() {
    _projectsSubscription?.cancel();
    return super.close();
  }
}
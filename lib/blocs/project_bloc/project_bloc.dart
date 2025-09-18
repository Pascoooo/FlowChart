import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

/// Gestisce lo stato e la logica di business per i progetti, orchestrando
/// il ciclo di vita delle sessioni di lavoro secondo l'architettura User-Driven Recovery.
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepo projectRepository;
  StreamSubscription? _projectsSubscription;

  ProjectBloc({required this.projectRepository}) : super(const ProjectInitial()) {
    // Eventi del ciclo di vita della sessione
    on<CheckForUnsavedSessions>(_onCheckForUnsavedSessions);
    on<RecoverSession>(_onRecoverSession);
    on<DiscardSession>(_onDiscardSession);
    on<LoadProjects>(_onLoadProjects);
    on<StartSessionAndSelectProject>(_onStartSessionAndSelectProject);
    on<LeaveProject>(_onLeaveProject);

    // Eventi di notifica e CRUD
    on<ProjectsUpdated>(_onProjectsUpdated);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
  }

  /// 1. Controlla se ci sono sessioni non salvate all'avvio dell'app.
  Future<void> _onCheckForUnsavedSessions(CheckForUnsavedSessions event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Verifica dati...'));
    try {
      final pendingSession = await projectRepository.checkForPendingSessions();
      if (pendingSession != null) {
        emit(UnsavedChangesFound(
            projectId: pendingSession.projectId,
            projectName: pendingSession.projectName));
      } else {
        add(const LoadProjects()); // Nessuna sessione trovata, carica i progetti normalmente
      }
    } catch (e) {
      emit(const ProjectError(message: 'Impossibile verificare le sessioni.'));
    }
  }

  /// 2a. L'utente ha scelto di recuperare la sessione.
  Future<void> _onRecoverSession(RecoverSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Recupero in corso...'));
    try {
      await projectRepository.recoverSession(event.projectId);
      add(const LoadProjects()); // Dopo il recupero, carica i progetti
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante il recupero della sessione.'));
    }
  }

  /// 2b. L'utente ha scelto di scartare la sessione.
  Future<void> _onDiscardSession(DiscardSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Eliminazione dati...'));
    try {
      await projectRepository.discardSession(event.projectId);
      add(const LoadProjects()); // Dopo aver scartato, carica i progetti
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante l\'eliminazione della sessione.'));
    }
  }

  /// 3. Carica la lista dei progetti e si mette in ascolto di aggiornamenti.
  Future<void> _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Caricamento progetti...'));
    await _projectsSubscription?.cancel();
    _projectsSubscription = projectRepository.projects().listen(
            (projects) => add(ProjectsUpdated(projects)),
        onError: (_) => emit(const ProjectError(message: 'Errore di connessione.'))
    );
  }

  /// 4. Aggiorna lo stato quando lo stream di Firestore emette nuovi dati.
  void _onProjectsUpdated(ProjectsUpdated event, Emitter<ProjectState> emit) {
    // Ordina per data di modifica, la sorgente della verità ora è solo Firestore
    final projects = event.projects..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    emit(ProjectsLoaded(projects: projects));
  }

  /// 5. Prepara il "banco di lavoro" e naviga nel workspace.
  Future<void> _onStartSessionAndSelectProject(StartSessionAndSelectProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;

    emit(const ProjectLoading(message: 'Preparazione ambiente...'));
    try {
      await projectRepository.startWorkspaceSession(event.project);
      emit(currentState.copyWith(selectedProject: event.project));
    } catch (e) {
      emit(currentState.copyWith(error: 'Impossibile avviare la sessione di lavoro.'));
    }
  }

  /// 6. Salva il "banco di lavoro" nell'"archivio" e torna alla dashboard.
  Future<void> _onLeaveProject(LeaveProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    final projectId = currentState.selectedProject?.projectId;

    if (projectId == null) return;

    emit(const ProjectLoading(message: 'Salvataggio in corso...'));
    try {
      await projectRepository.endWorkspaceSession(projectId);
      // Dopo il salvataggio, torna allo stato con la lista dei progetti senza nessuna selezione
      emit(currentState.copyWith(clearSelectedProject: true));
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore critico durante il salvataggio.'));
    }
  }

  /// Gestisce la creazione di un nuovo progetto.
  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    try {
      final newProject = await projectRepository.createProject(name: event.projectName.trim());

      // Crea il contenuto di default con la forma "Start" per il file 'main'
      final String startShapeId = 'start_${DateTime.now().microsecondsSinceEpoch}';
      final Map<String, dynamic> defaultShapeData = {
        'id': startShapeId, 'type': 'circle', 'x': 120.0, 'y': 120.0,
        'properties': {'width': 90.0, 'height': 90.0, 'text': 'Start'},
      };
      final String initialContent = jsonEncode([defaultShapeData]);

      await projectRepository.addFileToProject(
          projectId: newProject.projectId,
          fileName: 'main',
          content: initialContent
      );

      // Dopo la creazione, avvia direttamente la sessione ed entra nel nuovo progetto
      add(StartSessionAndSelectProject(project: newProject));
    } catch (e) {
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: 'Errore nella creazione del progetto.'));
      } else {
        emit(const ProjectError(message: 'Errore nella creazione del progetto.'));
      }
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
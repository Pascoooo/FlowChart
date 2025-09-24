import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui'; // AGGIUNTO per Offset usato nella factory
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:uuid/uuid.dart';
import 'project_event.dart';
import 'project_state.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart'; // AGGIUNTO per usare la factory

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepo projectRepository;
  StreamSubscription? _projectsSubscription;

  ProjectBloc({required this.projectRepository}) : super(const ProjectInitial()) {
    on<CheckForUnsavedSessions>(_onCheckForUnsavedSessions);
    on<RecoverSession>(_onRecoverSession);
    on<DiscardSession>(_onDiscardSession);
    on<LoadProjects>(_onLoadProjects);
    on<StartSessionAndSelectProject>(_onStartSessionAndSelectProject);
    on<LeaveProject>(_onLeaveProject);
    on<ProjectsUpdated>(_onProjectsUpdated);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
    on<RecoverSingleFile>(_onRecoverSingleFile);
    on<DiscardSingleFileChange>(_onDiscardSingleFileChange);
    on<UpdateProjectVisibility>(_onUpdateProjectVisibility);
    on<LoadStaticWorkspace>(_onLoadStaticWorkspace);
  }

  Future<void> _onCheckForUnsavedSessions(CheckForUnsavedSessions event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Verifica dati...'));
    try {
      final pendingSession = await projectRepository.checkForPendingSessions();
      if (pendingSession != null && pendingSession.changedFiles.isNotEmpty) {
        emit(UnsavedChangesFound(
          projectId: pendingSession.projectId,
          projectName: pendingSession.projectName,
          changedFiles: pendingSession.changedFiles,
        ));
      } else {
        add(const LoadProjects());
      }
    } catch (e) {
      emit(const ProjectError(message: 'Impossibile verificare le sessioni.'));
    }
  }

  Future<void> _onRecoverSession(RecoverSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Recupero in corso...'));
    try {
      await projectRepository.recoverSession(event.projectId);
      add(const LoadProjects());
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante il recupero della sessione.'));
    }
  }

  Future<void> _onDiscardSession(DiscardSession event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Eliminazione dati...'));
    try {
      await projectRepository.discardSession(event.projectId);
      add(const LoadProjects());
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante l\'eliminazione della sessione.'));
    }
  }

  // NUOVI HANDLER PER LE AZIONI MANUALI
  Future<void> _onRecoverSingleFile(RecoverSingleFile event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.recoverSingleFile(
        projectId: event.projectId,
        fileId: event.fileId,
        rtdbContent: event.rtdbContent,
      );
    } catch (e) {
    }
  }

  Future<void> _onDiscardSingleFileChange(DiscardSingleFileChange event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.discardSingleFileChange(
        projectId: event.projectId,
        fileId: event.fileId,
      );
    } catch (e) {
    }
  }

  Future<void> _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading(message: 'Caricamento progetti...'));
    await _projectsSubscription?.cancel();
    _projectsSubscription = projectRepository.projects().listen(
            (projects) => add(ProjectsUpdated(projects)),
        onError: (_) => emit(const ProjectError(message: 'Errore di connessione.'))
    );
  }

  void _onProjectsUpdated(ProjectsUpdated event, Emitter<ProjectState> emit) {
    final projects = event.projects..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    emit(ProjectsLoaded(projects: projects));
  }

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

  Future<void> _onLeaveProject(LeaveProject event, Emitter<ProjectState> emit) async {
    // Nuova gestione: se siamo in vista statica condivisa
    if (state is StaticWorkspaceLoaded) {
      emit(const ProjectLoading(message: 'Uscita...'));
      add(const LoadProjects());
      return;
    }

    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    final projectId = currentState.selectedProject?.projectId;

    if (projectId == null) return;

    // Se è una vista sola lettura (progetto condiviso) non eseguo endWorkspaceSession
    if (currentState.isReadOnlyView) {
      final updated = currentState.copyWith(clearSelectedProject: true);
      emit(updated);
      if (updated.projects.isEmpty) {
        add(const LoadProjects());
      }
      return;
    }

    emit(const ProjectLoading(message: 'Salvataggio in corso...'));
    try {
      await projectRepository.endWorkspaceSession(projectId);
      final cleared = currentState.copyWith(clearSelectedProject: true);
      emit(cleared);
      if (cleared.projects.isEmpty) {
        add(const LoadProjects());
      }
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore critico durante il salvataggio.'));
    }
  }

  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    try {
      // 1. Crea il nuovo progetto (questo non cambia)
      final newProject = await projectRepository.createProject(name: event.projectName.trim());

      // 2. Crea il contenuto iniziale usando i NUOVI modelli

      // Usa la nuova factory per creare il nodo di start
      final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(120.0, 120.0));

      // Crea un oggetto Flowchart completo
      final initialFlowchart = Flowchart(
        flowchartId: const Uuid().v4(), // Diamo un ID anche al flowchart stesso
        name: 'main', // Nome del file iniziale
        schemaVersion: kFlowNodeSchemaVersion, // Usa la costante definita nei modelli
        nodes: [startNode],
        edges: const [],
      );

      // Converte il flowchart in un'entità e poi in un documento mappa, pronto per il JSON
      final initialContent = jsonEncode(initialFlowchart.toEntity().toDocument());

      // 3. Aggiunge il file "main" al progetto con il contenuto appena creato
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: initialContent,
      );

      // 4. Avvia la sessione e seleziona il nuovo progetto
      add(StartSessionAndSelectProject(project: newProject));

    } catch (e) {
      // La gestione dell'errore rimane invariata
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: 'Errore nella creazione del progetto.'));
      } else {
        emit(const ProjectError(message: 'Errore nella creazione del progetto.'));
      }
    }
  }

  Future<void> _onDeleteProject(DeleteProject event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.deleteProject(projectId: event.projectId);
    } catch (e) {
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: 'Errore durante l\'eliminazione.'));
      }
    }
  }

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


  Future<void> _onUpdateProjectVisibility(
      UpdateProjectVisibility event,
      Emitter<ProjectState> emit,
      ) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;

    try {
      await projectRepository.updateProjectVisibility(
        projectId: event.projectId,
        isPublic: event.isPublic,
      );

      // --- MIGLIORAMENTO: Aggiorna lo stato della UI immediatamente ---
      // Troviamo l'indice del progetto modificato nella lista attuale
      final projectIndex = currentState.projects.indexWhere((p) => p.projectId == event.projectId);
      if (projectIndex != -1) {
        // Creiamo una nuova lista di progetti aggiornata
        final updatedProjects = List<MyProject>.from(currentState.projects);
        // Aggiorniamo il singolo progetto con il nuovo stato di visibilità
        // (Nota: lastVisibilityChange si aggiornerà al prossimo caricamento da Firestore)
        updatedProjects[projectIndex] = updatedProjects[projectIndex].copyWith(isPublic: event.isPublic);
        // Emettiamo il nuovo stato con la lista aggiornata per una reattività istantanea
        emit(currentState.copyWith(projects: updatedProjects));
      }

    } on VisibilityChangeRateLimitException catch (e) {
      final remaining = e.remaining;
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);

      String errorMessage;
      if (hours > 0) {
        errorMessage = 'Attendi ancora $hours ore e $minutes minuti.';
      } else {
        errorMessage = 'Attendi ancora $minutes minuti.';
      }
      emit(currentState.copyWith(error: errorMessage));
    } catch (e, st) {
      log('Errore in _onUpdateProjectVisibility: $e', stackTrace: st);
      emit(currentState.copyWith(error: 'Impossibile aggiornare la visibilità. Riprova.'));
    }
  }

  Future<void> _onLoadStaticWorkspace(
      LoadStaticWorkspace event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading(message: 'Caricamento progetto condiviso...'));
    final projectId = event.projectId.trim();

    if (projectId.isEmpty) {
      emit(const ProjectError(message: 'L\'ID del progetto non può essere vuoto.'));
      return;
    }

    try {
      final result = await projectRepository.getPublicProjectWithFiles(projectId);

      if (result == null) {
        emit(const ProjectError(message: 'Progetto non trovato o non pubblico.'));
        return;
      }

      emit(StaticWorkspaceLoaded(
        project: result['project'] as MyProject,
        files: result['files'] as List<MyFile>,
      ));

    } catch (e, st) {
      log('Errore in _onLoadStaticWorkspace: $e', stackTrace: st);
      emit(const ProjectError(message: 'Impossibile caricare il progetto condiviso.'));
    }
  }
  @override
  Future<void> close() {
    _projectsSubscription?.cancel();
    return super.close();
  }
}
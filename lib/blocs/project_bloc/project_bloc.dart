import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:project_repository/project_repository.dart';
import 'package:uuid/uuid.dart';
import '../flowchart_bloc/flowchart_shape_factory.dart';
import 'project_event.dart';
import 'project_state.dart';

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

  Future<void> _onRecoverSingleFile(RecoverSingleFile event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.recoverSingleFile(
        projectId: event.projectId,
        fileId: event.fileId,
        rtdbContent: event.rtdbContent,
      );
    } catch (e) {
      // Gestione errore (opzionale, potrebbe essere gestito a livello UI)
    }
  }

  Future<void> _onDiscardSingleFileChange(DiscardSingleFileChange event, Emitter<ProjectState> emit) async {
    try {
      await projectRepository.discardSingleFileChange(
        projectId: event.projectId,
        fileId: event.fileId,
      );
    } catch (e) {
      // Gestione errore
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
    final projects = List<MyProject>.from(event.projects)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
    if (state is StaticWorkspaceLoaded) {
      emit(const ProjectLoading(message: 'Uscita...'));
      add(const LoadProjects());
      return;
    }

    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    final projectId = currentState.selectedProject?.projectId;

    if (projectId == null) return;

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

      // ✅ FIX: Aggiornamento ottimistico anche all'uscita dal progetto.
      // Aggiorniamo l'orario del progetto appena chiuso e riordiniamo la lista
      // PRIMA di emettere lo stato, così la UI riceve subito l'ordine corretto.
      final projectIndex = currentState.projects.indexWhere((p) => p.projectId == projectId);
      if (projectIndex != -1) {
        final updatedProjects = List<MyProject>.from(currentState.projects);
        updatedProjects[projectIndex] = updatedProjects[projectIndex].copyWith(updatedAt: DateTime.now());
        updatedProjects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        emit(ProjectsLoaded(
          projects: updatedProjects,
          selectedProject: null, // Esci dal progetto
        ));

        if (updatedProjects.isEmpty) {
          add(const LoadProjects());
        }
      } else {
        // Fallback se il progetto non viene trovato (raro)
        final cleared = currentState.copyWith(clearSelectedProject: true);
        emit(cleared);
        if (cleared.projects.isEmpty) {
          add(const LoadProjects());
        }
      }
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore critico durante il salvataggio.'));
    }
  }

  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    if (state is ProjectsLoaded) {
      final currentState = state as ProjectsLoaded;
      final newNameLower = event.projectName.trim().toLowerCase();
      if (currentState.projects.any((p) => p.name.toLowerCase() == newNameLower)) {
        emit(currentState.copyWith(error: 'Un progetto con questo nome esiste già.'));
        emit(currentState.copyWith(clearError: true));
        return;
      }
    }

    try {
      final newProject = await projectRepository.createProject(name: event.projectName.trim());

      final startNode = FlowNodeFactory.createNode(FlowNodeKind.start, const Offset(1030.0, 50.0), allVariables:  []);
      const mainSignature = FlowchartSignature(returnType: 'int');

      final initialFlowchart = Flowchart(
        flowchartId: const Uuid().v4(),
        name: 'main',
        schemaVersion: kFlowNodeSchemaVersion,
        signature: mainSignature,
        nodes: [startNode],
        edges: const [],
        variables: const [],
      );

      final initialContent = jsonEncode(initialFlowchart.toEntity().toDocument());
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: initialContent,
      );

      add(StartSessionAndSelectProject(project: newProject));

    } catch (e) {
      final errorMessage = 'Errore nella creazione del progetto.';
      if (state is ProjectsLoaded) {
        emit((state as ProjectsLoaded).copyWith(error: errorMessage));
      } else {
        emit(ProjectError(message: errorMessage));
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
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;

    final newNameLower = event.newName.trim().toLowerCase();
    if (currentState.projects.any((p) => p.projectId != event.projectId && p.name.toLowerCase() == newNameLower)) {
      emit(currentState.copyWith(error: 'Un progetto con questo nome esiste già.'));
      emit(currentState.copyWith(clearError: true));
      return;
    }

    try {
      await projectRepository.renameProject(
          projectId: event.projectId, newName: event.newName.trim());
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore durante la rinomina.'));
    }
  }

  Future<void> _onUpdateProjectVisibility(UpdateProjectVisibility event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;

    try {
      await projectRepository.updateProjectVisibility(
        projectId: event.projectId,
        isPublic: event.isPublic,
      );

      // Rimuoviamo l'aggiornamento ottimistico locale. L'ordinamento è ora gestito dalla UI.
      final projectIndex = currentState.projects.indexWhere((p) => p.projectId == event.projectId);
      if (projectIndex != -1) {
        final updatedProjects = List<MyProject>.from(currentState.projects);
        updatedProjects[projectIndex] = updatedProjects[projectIndex].copyWith(isPublic: event.isPublic);
        emit(currentState.copyWith(projects: updatedProjects));
      }

    } on VisibilityChangeRateLimitException catch (e) {
      final remaining = e.remaining;
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      String errorMessage = (hours > 0)
          ? 'Attendi ancora $hours ore e $minutes minuti.'
          : 'Attendi ancora $minutes minuti.';
      emit(currentState.copyWith(error: errorMessage));
    } catch (e) {
      emit(currentState.copyWith(error: 'Impossibile aggiornare la visibilità. Riprova.'));
    }
  }

  Future<void> _onLoadStaticWorkspace(LoadStaticWorkspace event, Emitter<ProjectState> emit) async {
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
    } catch (e) {
      emit(const ProjectError(message: 'Errore durante il caricamento del progetto.'));
    }
  }

  @override
  Future<void> close() {
    _projectsSubscription?.cancel();
    return super.close();
  }
}
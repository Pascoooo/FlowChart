import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // AGGIUNTO per Offset usato nella factory
import 'package:bloc/bloc.dart';
import 'package:flowchart_thesis/config/services/dialog_service.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';
import '../flowchart_bloc/FlowchartShapeFactory.dart'; // AGGIUNTO per usare la factory

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
    // NUOVI HANDLER
    on<RecoverSingleFile>(_onRecoverSingleFile);
    on<DiscardSingleFileChange>(_onDiscardSingleFileChange);
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
    if (state is! ProjectsLoaded) return;
    final currentState = state as ProjectsLoaded;
    final projectId = currentState.selectedProject?.projectId;

    if (projectId == null) return;

    emit(const ProjectLoading(message: 'Salvataggio in corso...'));
    try {
      await projectRepository.endWorkspaceSession(projectId);
      emit(currentState.copyWith(clearSelectedProject: true));
    } catch (e) {
      emit(currentState.copyWith(error: 'Errore critico durante il salvataggio.'));
    }
  }

  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    try {
      final newProject = await projectRepository.createProject(name: event.projectName.trim());
      // CREAZIONE UNIFICATA CONTENUTO INIZIALE (schema nuovo)
      final startShape = FlowchartShapeFactory.createShape(ShapeType.start, const Offset(120.0, 120.0));
      final initialContent = jsonEncode({
        'shapes': [startShape.toJson()],
        'connections': [],
      });
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: initialContent,
      );
      add(StartSessionAndSelectProject(project: newProject));
    } catch (e) {
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

  @override
  Future<void> close() {
    _projectsSubscription?.cancel();
    return super.close();
  }
}
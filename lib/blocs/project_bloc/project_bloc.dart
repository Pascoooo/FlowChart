// pascoooo/flowchart/FlowChart-rework/lib/blocs/project_bloc/project_bloc.dart

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'project_event.dart';
import 'project_state.dart';

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepo projectRepository;

  StreamSubscription? _projectsSubscription;
  Map<String, DateTime> _timestamps = {};

  ProjectBloc({
    required this.projectRepository,
  }) : super(const ProjectInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<ProjectsUpdated>(_onProjectsUpdated);
    on<SelectProject>(_onSelectProject);
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
    on<DeselectProject>(_onDeselectProject);
    on<ProjectsStreamFailed>(_onProjectsStreamFailed);
  }

  Future<void> _onLoadProjects(LoadProjects event, Emitter<ProjectState> emit) async {
    emit(const ProjectLoading());
    await _projectsSubscription?.cancel();
    try {
      _timestamps = await projectRepository.getUserTimestamps();
      _projectsSubscription = projectRepository.projects().listen((projects) {
        add(ProjectsUpdated(projects));
      }, onError: (error) {
        add(ProjectsStreamFailed(error));
      });
    } catch (e) {
      emit(const ProjectError(message: 'Impossibile caricare i dati iniziali.'));
    }
  }

  void _onProjectsUpdated(ProjectsUpdated event, Emitter<ProjectState> emit) {
    MyProject? currentSelectedProject;
    if (state is ProjectsLoaded) {
      currentSelectedProject = (state as ProjectsLoaded).selectedProject;
    }

    final projects = event.projects;
    projects.sort((a, b) {
      final timeA = _timestamps[a.projectId] ?? a.updatedAt;
      final timeB = _timestamps[b.projectId] ?? b.updatedAt;
      return timeB.compareTo(timeA);
    });

    if (currentSelectedProject != null) {
      try {
        currentSelectedProject = projects.firstWhere((p) => p.projectId == currentSelectedProject!.projectId);
      } catch (e) {
        currentSelectedProject = null;
      }
    }

    emit(ProjectsLoaded(projects: projects, selectedProject: currentSelectedProject));
  }

  Future<void> _onSelectProject(SelectProject event, Emitter<ProjectState> emit) async {
    if (state is ProjectsLoaded) {
      final currentState = state as ProjectsLoaded;
      _timestamps[event.project.projectId] = DateTime.now();

      try {
        await projectRepository.saveUserTimestamps(_timestamps);
      } catch (e) {
        emit(currentState.copyWith(error: "Errore durante la sincronizzazione."));
      }

      final updatedList = List<MyProject>.from(currentState.projects);
      updatedList.sort((a, b) {
        final timeA = _timestamps[a.projectId] ?? a.updatedAt;
        final timeB = _timestamps[b.projectId] ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });
      emit(currentState.copyWith(projects: updatedList, selectedProject: event.project));
    }
  }

  Future<void> _onCreateProject(CreateProject event, Emitter<ProjectState> emit) async {
    final currentState = state;
    emit(const ProjectLoading());
    try {
      final newProject = await projectRepository.createProject(name: event.projectName.trim());
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: '',
      );
      _timestamps[newProject.projectId] = newProject.updatedAt;

      // Salva immediatamente anche alla creazione
      await projectRepository.saveUserTimestamps(_timestamps);

      List<MyProject> updatedList;
      if (currentState is ProjectsLoaded) {
        updatedList = List<MyProject>.from(currentState.projects)..add(newProject);
      } else {
        updatedList = [newProject];
      }

      updatedList.sort((a, b) {
        final timeA = _timestamps[a.projectId] ?? a.updatedAt;
        final timeB = _timestamps[b.projectId] ?? b.updatedAt;
        return timeB.compareTo(timeA);
      });

      emit(ProjectsLoaded(projects: updatedList, selectedProject: newProject));
    } catch (e) {
      emit(const ProjectError(message: 'Errore nella creazione del progetto.'));
      if (currentState is ProjectsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteProject(DeleteProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;

    final currentState = state as ProjectsLoaded;
    final originalProjects = List<MyProject>.from(currentState.projects);
    final updatedProjects = originalProjects.where((p) => p.projectId != event.projectId).toList();

    emit(currentState.copyWith(
      projects: updatedProjects,
      clearSelectedProject: currentState.selectedProject?.projectId == event.projectId,
    ));

    try {
      await projectRepository.deleteProject(projectId: event.projectId);
    } catch (e) {
      emit(currentState.copyWith(
        projects: originalProjects,
        error: 'Errore nella cancellazione del progetto.',
      ));
    }
  }

  Future<void> _onRenameProject(RenameProject event, Emitter<ProjectState> emit) async {
    if (state is! ProjectsLoaded) return;

    final currentState = state as ProjectsLoaded;
    final originalProjects = List<MyProject>.from(currentState.projects);
    final updatedProjects = currentState.projects.map((project) {
      if (project.projectId == event.projectId) {
        return project.copyWith(name: event.newName.trim());
      }
      return project;
    }).toList();

    emit(currentState.copyWith(projects: updatedProjects));

    try {
      await projectRepository.renameProject(
          projectId: event.projectId, newName: event.newName.trim());
    } catch (e) {
      emit(currentState.copyWith(
        projects: originalProjects,
        error: 'Errore durante la rinomina del progetto.',
      ));
    }
  }

  void _onDeselectProject(DeselectProject event, Emitter<ProjectState> emit) {
    if (state is ProjectsLoaded) {
      emit((state as ProjectsLoaded).copyWith(clearSelectedProject: true));
    }
  }

  void _onProjectsStreamFailed(ProjectsStreamFailed event, Emitter<ProjectState> emit) {
    if (state is ProjectError) return;
    emit(const ProjectError(message: 'Errore di connessione.'));
  }

  @override
  Future<void> close() {
    _projectsSubscription?.cancel();
    return super.close();
  }
}
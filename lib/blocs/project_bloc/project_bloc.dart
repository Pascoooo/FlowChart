import 'package:bloc/bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Per WriteBatch
import 'dart:developer' as developer;
import 'logger_service.dart';
import 'project_event.dart';
import 'project_state.dart';


class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final FirebaseProjectRepo projectRepository;
  // AGGIUNTO: Inietta il servizio di logging
  final UpdateLoggerService updateLoggerService;

  ProjectBloc({
    required this.projectRepository,
    // AGGIUNTO: Richiedi il servizio nel costruttore
    required this.updateLoggerService,
  }) : super(const ProjectInitial()) {
    on<CreateProject>(_onCreateProject);
    on<DeleteProject>(_onDeleteProject);
    on<RenameProject>(_onRenameProject);
    on<LoadProjects>(_onLoadProjects);
    on<SelectProject>(_onSelectProject);
    on<DeselectProject>(_onDeselectProject);
  }

  // MODIFICATO: La funzione di caricamento ora sincronizza prima gli aggiornamenti pendenti
  Future<void> _onLoadProjects(
      LoadProjects event,
      Emitter<ProjectState> emit,
      ) async {
    emit(const ProjectLoading());
    try {
      // 1. Controlla e sincronizza gli aggiornamenti pendenti
      await _syncPendingUpdates();

      // 2. Procedi con il caricamento normale
      final projects = await projectRepository.getProjects();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(ProjectsLoaded(projects: projects, selectedProject: null));
    } catch (e) {
      developer.log('Errore durante il caricamento dei progetti: $e', error: e);
      emit(const ProjectError(message: 'Errore nel caricamento dei progetti. Riprova più tardi.'));
    }
  }

  /// Funzione helper per sincronizzare gli aggiornamenti
  Future<void> _syncPendingUpdates() async {
    final pendingUpdates = await updateLoggerService.getPendingUpdates();
    if (pendingUpdates.isNotEmpty) {
      developer.log('Trovati ${pendingUpdates.length} aggiornamenti pendenti. Sincronizzazione in corso...');
      try {
        await projectRepository.updateProjectTimestamps(pendingUpdates);
        // La sincronizzazione è andata a buon fine, cancella il file locale
        await updateLoggerService.deletePendingUpdatesFile();
        developer.log('Sincronizzazione completata con successo.');
      } catch (e) {
        // Se la sincronizzazione fallisce, non cancelliamo il file
        // e lasciamo un log dell'errore. L'app continuerà a funzionare
        // con i dati vecchi e riproverà al prossimo avvio.
        developer.log('Sincronizzazione fallita! Gli aggiornamenti verranno ritentati al prossimo avvio.', error: e);
      }
    } else {
      developer.log('Nessun aggiornamento pendente da sincronizzare.');
    }
  }


  // MODIFICATO: La selezione ora aggiorna lo stato localmente e registra l'update.
  Future<void> _onSelectProject(
      SelectProject event,
      Emitter<ProjectState> emit,
      ) async {
    if (state is ProjectsLoaded) {
      final currentState = state as ProjectsLoaded;

      // 1. Registra l'apertura del progetto nel file locale
      await updateLoggerService.logProjectUpdate(event.project.projectId);

      // 2. Aggiorna l'ordine nell'UI immediatamente (aggiornamento ottimistico)
      final List<MyProject> updatedList = List.from(currentState.projects);

      // Rimuovi il progetto selezionato e reinseriscilo in cima
      updatedList.removeWhere((p) => p.projectId == event.project.projectId);
      updatedList.insert(0, event.project.copyWith(updatedAt: DateTime.now())); // Aggiorna il timestamp localmente

      // 3. Emetti il nuovo stato senza attendere operazioni di rete
      emit(ProjectsLoaded(
        projects: updatedList,
        selectedProject: event.project,
      ));
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

      final existingProjects = await projectRepository.getProjects();
      if (existingProjects.any((p) => p.name == event.projectName.trim())) {
        throw Exception('Nome già in uso.');
      }

      await projectRepository.createProject(name: event.projectName.trim());
      final projects = await projectRepository.getProjects();

      final newProject = projects.firstWhere((p) => p.name == event.projectName.trim());
      await projectRepository.addFileToProject(
        projectId: newProject.projectId,
        fileName: 'main',
        content: '',
      );

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

      MyProject? selectedProject;
      if (currentState is ProjectsLoaded &&
          currentState.selectedProject?.projectId != event.projectId) {
        selectedProject = currentState.selectedProject;
      }

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

      final existingProjects = await projectRepository.getProjects();
      if (existingProjects.any(
            (p) => p.name == event.newName.trim() && p.projectId != event.projectId,
      )) {
        throw Exception('Nome già in uso.');
      }

      await projectRepository.renameProject(
        projectId: event.projectId,
        newName: event.newName.trim(),
      );

      final projects = await projectRepository.getProjects();

      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

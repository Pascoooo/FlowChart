import 'package:flowchart_thesis/config/services/dialog_service.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_selection/views/project_selector.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/project_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../config/error/error_page.dart';
import '../../config/services/banner_service.dart';
import 'animations/background_animation.dart';
import 'animations/project_loading_indicator.dart';

const Duration _kTransitionDuration = Duration(milliseconds: 300);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // NUOVO PUNTO DI INIZIO: Avvia il controllo per sessioni non salvate.
    context.read<ProjectBloc>().add(const CheckForUnsavedSessions());
  }

  /// Mostra il dialogo di recupero quando viene rilevata una sessione non salvata.
  void _showRecoveryDialog(BuildContext context, UnsavedChangesFound state) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool? wantsToRecover = await DialogService.showConfirmationDialog(
        context,
        title: "Lavoro non salvato",
        message:
        "Abbiamo trovato una sessione di lavoro non salvata per il progetto '${state.projectName}'. Vuoi recuperarla?",
        confirmText: "Recupera",
        cancelText: "Scarta",
      );

      if (!mounted) return;

      if (wantsToRecover == true) {
        context.read<ProjectBloc>().add(RecoverSession(projectId: state.projectId));
      } else {
        // L'utente ha premuto "Scarta" o ha chiuso il dialogo
        context.read<ProjectBloc>().add(DiscardSession(projectId: state.projectId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          BlocListener<ProjectBloc, ProjectState>(
            listener: (context, state) {
              // Mostra il dialogo di recupero quando lo stato è UnsavedChangesFound
              if (state is UnsavedChangesFound) {
                _showRecoveryDialog(context, state);
              }
              // Mostra un banner per errori non bloccanti
              else if (state is ProjectsLoaded && state.error != null) {
                BannerService.showError(context, state.error!);
              }
            },
            child: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                // Gestisce tutti gli stati di caricamento e iniziali
                if (state is ProjectInitial || state is ProjectLoading || state is UnsavedChangesFound) {
                  return const ModernLoadingIndicator();
                }
                // Gestisce gli errori bloccanti
                if (state is ProjectError) {
                  return ErrorPage(error: state.message);
                }
                // Gestisce lo stato principale con i dati caricati
                if (state is ProjectsLoaded) {
                  return _buildProjectsLoadedView(state);
                }
                // Fallback per ogni altro caso
                return const ModernLoadingIndicator();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsLoadedView(ProjectsLoaded state) {
    return AnimatedSwitcher(
      duration: _kTransitionDuration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isSelector = child.key == const ValueKey('project-selector');
        final offset = isSelector ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);

        return SlideTransition(
          position: Tween<Offset>(begin: offset, end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: state.selectedProject != null
          ? ProjectWorkspace(
        key: ValueKey('workspace-${state.selectedProject!.projectId}'),
        selectedProject: state.selectedProject!,
      )
          : ProjectSelector(
        key: const ValueKey('project-selector'),
        projects: state.projects,
        onProjectSelected: (project) {
          context.read<ProjectBloc>().add(StartSessionAndSelectProject(project: project));
        },
        onCreateProject: (name) {
          context.read<ProjectBloc>().add(CreateProject(projectName: name));
        },
      ),
    );
  }
}
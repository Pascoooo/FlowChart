import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/static_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../config/error/error_page.dart';
import '../../config/services/banner_service.dart';
import '../../config/services/dialog_service/app_dialogs.dart';
import '../../config/services/dialog_service/recovery_dialogs.dart';
import 'animations/background_animation.dart';
import 'animations/project_loading_indicator.dart';
import 'project_selection/views/project_selector.dart';
import 'project_workspace/widgets/project_workspace.dart';

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
    context.read<ProjectBloc>().add(const CheckForUnsavedSessions());
  }

  /// **CORRETTO**: Gestisce la logica di recupero in modo asincrono.
  void _showRecoveryDialog(BuildContext context, UnsavedChangesFound state) {
    WidgetsBinding.instance.addPostFrameCallback((_) async { // Aggiunto async
      // Attendiamo che l'utente faccia una scelta nel dialogo.
      final action = await AppDialogs.showInitialRecoveryDialog(
        context: context,
        projectName: state.projectName,
      );
      if (!mounted) return;
      switch (action) {
        case RecoveryAction.recoverAll:
          context.read<ProjectBloc>().add(RecoverSession(projectId: state.projectId));
          break;
        case RecoveryAction.discardAll:
          context.read<ProjectBloc>().add(DiscardSession(projectId: state.projectId));
          break;
        case RecoveryAction.manualSelect:
        // Anche la chiamata al dialogo manuale è ora asincrona.
          await _showManualRecoveryDialog(context, state);
          break;
        default:
        // L'utente potrebbe aver chiuso il dialogo in modo imprevisto.
        // Ricarichiamo i progetti per sicurezza.
          context.read<ProjectBloc>().add(const LoadProjects());
          break;
      }
    });
  }

  /// **CORRETTO**: Attende il completamento del recupero manuale prima di procedere.
  Future<void> _showManualRecoveryDialog(
      BuildContext context, UnsavedChangesFound state) async {
    // Attendiamo che il dialogo manuale venga completato.
    final didComplete = await AppDialogs.showManualRecoveryDialog(
      context: context,
      state: state,
    );

    // Se il dialogo è stato completato, ricarichiamo i progetti.
    // L'evento viene inviato solo ora, in modo sicuro.
    if (didComplete == true && mounted) {
      context.read<ProjectBloc>().add(const LoadProjects());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          BlocListener<ProjectBloc, ProjectState>(
            listener: (context, state) {
              if (state is UnsavedChangesFound) {
                _showRecoveryDialog(context, state);
              } else if (state is ProjectsLoaded && state.error != null) {
                BannerService.showError(context, state.error!);
              }
            },
            child: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                if (state is ProjectInitial ||
                    state is ProjectLoading ||
                    state is UnsavedChangesFound) {
                  return const ModernLoadingIndicator();
                }
                if (state is ProjectError) {
                  return ErrorPage(error: state.message);
                }
                // --- NUOVA CONDIZIONE AGGIUNTA QUI ---
                if (state is StaticWorkspaceLoaded) {
                  // Se lo stato è quello per la vista statica, mostriamo il nuovo widget
                  return StaticProjectWorkspace(
                    key: ValueKey('static-workspace-${state.project.projectId}'),
                    project: state.project,
                    files: state.files,
                  );
                }

                if (state is ProjectsLoaded) {
                  return _buildProjectsLoadedView(state);
                }
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
      child: state.selectedProject != null
          ? ProjectWorkspace(
              key: ValueKey('workspace-${state.selectedProject!.projectId}'),
              selectedProject: state.selectedProject!,
              isReadOnly: state.isReadOnlyView,
              onLeave: () => context.read<ProjectBloc>().add(const LeaveProject()),
            )
          : ProjectSelector(
              key: const ValueKey('project-selector'),
              projects: state.projects,
              onProjectSelected: (project) => context
                  .read<ProjectBloc>()
                  .add(StartSessionAndSelectProject(project: project)),
              onCreateProject: (name) => context
                  .read<ProjectBloc>()
                  .add(CreateProject(projectName: name)),
            ),
    );
  }
}
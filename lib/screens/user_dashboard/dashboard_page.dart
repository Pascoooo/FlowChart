import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../config/error/error_page.dart';
import '../../config/services/banner_service.dart';
import 'animations/background_animation.dart';
import 'animations/project_loading_indicator.dart';
import 'project_selection/views/project_selector.dart';
import 'project_workspace/widgets/project_workspace.dart';
import 'project_selection/widgets/initial_recovery_dialog.dart';
import 'project_selection/widgets/manual_recovery_dialog.dart';

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

  void _showRecoveryDialog(BuildContext context, UnsavedChangesFound state) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return InitialRecoveryDialog(
            projectName: state.projectName,
            onRecoverAll: () {
              Navigator.of(dialogContext).pop();
              context.read<ProjectBloc>().add(RecoverSession(projectId: state.projectId));
            },
            onDiscardAll: () {
              Navigator.of(dialogContext).pop();
              context.read<ProjectBloc>().add(DiscardSession(projectId: state.projectId));
            },
            onManualSelect: () {
              Navigator.of(dialogContext).pop();
              _showManualRecoveryDialog(context, state);
            },
          );
        },
      );
    });
  }

  void _showManualRecoveryDialog(BuildContext context, UnsavedChangesFound state) {
    // --- MODIFICA CHIAVE ---
    // Poiché showDialog crea un nuovo contesto che non conosce il ProjectBloc,
    // dobbiamo fornirglielo esplicitamente usando BlocProvider.value.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        // Forniamo l'istanza del BLoC già esistente al sotto-albero del dialogo.
        value: context.read<ProjectBloc>(),
        child: ManualRecoveryDialog(state: state),
      ),
    );
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
                if (state is ProjectInitial || state is ProjectLoading || state is UnsavedChangesFound) {
                  return const ModernLoadingIndicator();
                }
                if (state is ProjectError) {
                  return ErrorPage(error: state.message);
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
      )
          : ProjectSelector(
        key: const ValueKey('project-selector'),
        projects: state.projects,
        onProjectSelected: (project) => context.read<ProjectBloc>().add(StartSessionAndSelectProject(project: project)),
        onCreateProject: (name) => context.read<ProjectBloc>().add(CreateProject(projectName: name)),
      ),
    );
  }
}
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/project_workspace.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/static_workspace.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../config/error/error_page.dart';
import '../../config/services/banner_service.dart';
import '../../config/services/dialog_service/recovery_dialogs.dart';
import 'animations/background_animation.dart';
import 'project_selection/views/project_selector.dart';

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

  // --- METODO DI INTERAZIONE CON I DIALOGHI COMPLETAMENTE RISCRITTO ---
  void _showRecoveryDialog(BuildContext context, UnsavedChangesFound state) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Chiama il nostro nuovo dialogo a due pulsanti, più pulito e diretto.
      final action = await RecoveryDialogs.showInitialRecoveryDialog(
        context: context,
        projectName: state.projectName,
      );

      if (!mounted) return;

      // La logica ora gestisce solo le due azioni possibili: manage o discard.
      switch (action) {
        case RecoveryAction.manage:
        // L'azione "Rivedi e Gestisci" porta direttamente al dialogo di confronto manuale.
          await _showManualRecoveryDialog(context, state);
          break;
        case RecoveryAction.discard:
        // L'azione "Scarta" invia l'evento per eliminare la sessione non salvata.
          context
              .read<ProjectBloc>()
              .add(DiscardSession(projectId: state.projectId));
          break;
        default:
        // Nel caso in cui il dialogo venga chiuso senza una scelta (es. tasto ESC),
        // si procede al caricamento standard dei progetti.
          context.read<ProjectBloc>().add(const LoadProjects());
          break;
      }
    });
  }

  // Questo metodo rimane valido, poiché il dialogo manuale esiste ancora nel nuovo flusso.
  Future<void> _showManualRecoveryDialog(
      BuildContext context, UnsavedChangesFound state) async {
    final didComplete = await RecoveryDialogs.showManualRecoveryDialog(
      context: context,
      state: state,
    );

    // Se il processo di recupero manuale è stato completato, si caricano i progetti.
    if (didComplete == true && mounted) {
      context.read<ProjectBloc>().add(const LoadProjects());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Stack(
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
                // La logica di costruzione della UI rimane invariata.
                // È robusta e gestisce correttamente i vari stati del BLoC.
                if (state is ProjectInitial ||
                    state is ProjectLoading ||
                    state is UnsavedChangesFound) {
                  return const Center(child: ProgressRing());
                }
                if (state is ProjectError) {
                  return ErrorPage(error: state.message);
                }
                if (state is StaticWorkspaceLoaded) {
                  return StaticProjectWorkspace(
                    key: ValueKey('static-workspace-${state.project.projectId}'),
                    project: state.project,
                    files: state.files,
                  );
                }
                if (state is ProjectsLoaded) {
                  return _buildProjectsLoadedView(state);
                }
                return const Center(child: ProgressRing());
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
        onLeave: () =>
            context.read<ProjectBloc>().add(const LeaveProject()),
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
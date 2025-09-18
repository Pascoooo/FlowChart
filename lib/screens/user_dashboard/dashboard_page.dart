import 'package:flowchart_thesis/screens/user_dashboard/project_selection/views/project_selector.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/project_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/file_bloc/file_system_bloc.dart';
import '../../blocs/file_bloc/file_system_event.dart';
import '../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../blocs/project_bloc/project_bloc.dart';
import '../../blocs/project_bloc/project_event.dart';
import '../../blocs/project_bloc/project_state.dart';
import '../../config/error/error_page.dart';
import '../../config/services/banner_service.dart';
import '../../config/services/dialog_service.dart';
import 'animations/background_animation.dart';
import 'animations/project_loading_indicator.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          BlocListener<ProjectBloc, ProjectState>(
            listenWhen: (prev, curr) =>
            curr is UnsavedChangesFound ||
                (curr is ProjectsLoaded && curr.error != null),
            listener: (context, state) {
              if (state is UnsavedChangesFound) {
                DialogService.showConfirmationDialog(
                  context,
                  title: "Lavoro non salvato trovato!",
                  message:
                  "Abbiamo trovato delle modifiche non salvate per il progetto '${state.projectName}'. Vuoi recuperarle?",
                  confirmText: "Recupera",
                  cancelText: "Scarta",
                ).then((shouldRecover) {
                  if (!mounted) return;
                  if (shouldRecover == true) {
                    context
                        .read<ProjectBloc>()
                        .add(RecoverSession(projectId: state.projectId));
                  } else {
                    context
                        .read<ProjectBloc>()
                        .add(DiscardSession(projectId: state.projectId));
                  }
                });
              }
              if (state is ProjectsLoaded && state.error != null) {
                BannerService.showError(context, state.error!);
              }
            },
            child: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                if (state is ProjectInitial || state is UnsavedChangesFound) {
                  return const ModernLoadingIndicator();
                }

                if (state is ProjectLoading) {
                  return const ModernLoadingIndicator();
                }

                if (state is ProjectsLoaded) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.selectedProject != null
                        ? MultiBlocProvider(
                      key: ValueKey(
                          'workspace-${state.selectedProject!.projectId}'),
                      providers: [
                        BlocProvider(create: (_) => FlowchartBloc()),
                        BlocProvider(
                          create: (context) => FileSystemBloc(
                            projectRepository: context
                                .read<ProjectBloc>()
                                .projectRepository,
                          )..add(RefreshFileSystem(
                              projectId: state.selectedProject!.projectId)),
                        ),
                      ],
                      child: ProjectWorkspace(
                          selectedProject: state.selectedProject!),
                    )
                        : ProjectSelector(
                      key: const ValueKey('project-selector'),
                      projects: state.projects,
                      onProjectSelected: (project) {
                        context
                            .read<ProjectBloc>()
                            .add(StartSessionAndSelectProject(project: project));
                      },
                      onCreateProject: (name) {
                        context
                            .read<ProjectBloc>()
                            .add(CreateProject(projectName: name));
                      },
                    ),
                  );
                }

                if (state is ProjectError) {
                  return ErrorPage(error: state.message);
                }

                return const ModernLoadingIndicator();
              },
            ),
          ),
        ],
      ),
    );
  }
}
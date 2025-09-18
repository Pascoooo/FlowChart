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
    context.read<ProjectBloc>().add(const LoadProjects());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          const AnimatedBackground(),
          BlocListener<ProjectBloc, ProjectState>(
            listener: (context, state) {
              if (state is ProjectsLoaded && state.error != null) {
                BannerService.showError(context, state.error!);
              }
            },
            child: BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                switch (state) {
                  case ProjectLoading():
                    return _buildLoadingView(theme);
                  case ProjectError():
                    return ErrorPage(error: state.message);
                  case ProjectsLoaded():
                    return _buildProjectsLoadedView(state, theme);
                  case ProjectInitial():
                    return _buildLoadingView(theme);
                  default:
                    return _buildLoadingView(theme);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return const ModernLoadingIndicator();
  }

  Widget _buildProjectsLoadedView(ProjectsLoaded state, ThemeData theme) {
    return AnimatedSwitcher(
      duration: _kTransitionDuration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isSelector = child.key == const ValueKey('project-selector');
        final offset = isSelector ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);

        return SlideTransition(
          position: Tween<Offset>(
            begin: offset,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
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
          context.read<ProjectBloc>().add(SelectProject(project: project));
        },
        onCreateProject: (name) {
          context.read<ProjectBloc>().add(CreateProject(projectName: name));
        },
      ),
    );
  }
}

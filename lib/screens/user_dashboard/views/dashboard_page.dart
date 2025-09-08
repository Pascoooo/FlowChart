import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../../../config/error/error_page.dart';
import '../animations/background_animation.dart';
import '../animations/project_loading_indicator.dart';
import '../../project_selection/views/project_selector.dart';
import '../widgets/project_workspace.dart';

const Duration _kTransitionDuration = Duration(milliseconds: 300);
const EdgeInsets _kSnackbarMargin = EdgeInsets.all(16.0);
const double _kSnackbarBorderRadius = 12.0;

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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error!),
                    backgroundColor: theme.colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    margin: _kSnackbarMargin,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_kSnackbarBorderRadius),
                    ),
                  ),
                );
              }
            },
            child: BlocBuilder<ProjectBloc, ProjectState>(
              buildWhen: (previous, current) {
                if (previous.runtimeType != current.runtimeType) return true;
                if (previous is ProjectsLoaded && current is ProjectsLoaded) {
                  return previous.selectedProject != current.selectedProject ||
                      previous.projects.length != current.projects.length;
                }
                return true;
              },
              builder: (context, state) {
                switch (state.runtimeType) {
                  case ProjectLoading:
                    return _buildLoadingView(theme);
                  case ProjectError:
                    final errorState = state as ProjectError;
                    return ErrorPage(
                      error: errorState.message,
                      onRetry: () {
                        context.read<ProjectBloc>().add(const LoadProjects());
                      },
                    );
                  case ProjectsLoaded:
                    return _buildProjectsLoadedView(state as ProjectsLoaded, theme);
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


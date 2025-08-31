import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../animations/background_animation.dart';
import '../widgets/project_selector.dart';
import '../error/error_view.dart';
import '../widgets/project_workspace.dart';

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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.98),
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            const AnimatedBackground(),
            BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                return _buildContent(context, state, theme);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProjectState state, ThemeData theme) {
    switch (state.runtimeType) {
      case ProjectLoading:
        return _buildLoadingView(theme);
      case ProjectError:
        return _buildErrorView(state as ProjectError);
      case ProjectsLoaded:
        return _buildProjectsLoadedView(state as ProjectsLoaded);
      default:
        return const CupertinoActivityIndicator(radius: 16);
    }
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoActivityIndicator(
            color: theme.colorScheme.primary,
            radius: 16,
          ),
          const SizedBox(height: 24),
          Text(
            "Caricamento progetti...",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ProjectError state) {
    return ErrorView(message: state.message);
  }

  Widget _buildProjectsLoadedView(ProjectsLoaded state) {
    if (state.selectedProject != null) {
      return ProjectWorkspace(
        selectedProject: state.selectedProject!,
      );
    } else {
      return ProjectSelector(
        projects: state.projects,
        onProjectSelected: (project) {
          context.read<ProjectBloc>().add(SelectProject(project: project));
        },
        onCreateProject: (name) {
          context.read<ProjectBloc>().add(CreateProject(projectName: name));
        },
      );
    }
  }
}
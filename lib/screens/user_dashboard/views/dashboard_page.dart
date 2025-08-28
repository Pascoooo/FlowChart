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

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    context.read<ProjectBloc>().add(const LoadProjects());
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
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
              theme.colorScheme.surfaceVariant.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            const AnimatedBackground(),
            BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, state) {
                if (state is ProjectLoading) {
                  return _buildLoadingView(theme);
                }
                if (state is ProjectError) {
                  return ErrorView(message: state.message);
                }
                if (state is ProjectsLoaded) {
                  if (state.selectedProject != null) {
                    // Quando un progetto è selezionato, avvia l'animazione forward
                    _transitionController.forward();
                    return _buildWorkspace(state);
                  } else {
                    // Quando nessun progetto è selezionato, avvia l'animazione reverse
                    _transitionController.reverse();
                    return _buildProjectSelector(state);
                  }
                }
                // Stato di fallback iniziale (es. ProjectInitial)
                return _buildLoadingView(theme);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 2,
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

  Widget _buildProjectSelector(ProjectsLoaded state) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_transitionController),
      child: ProjectSelector(
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

  Widget _buildWorkspace(ProjectsLoaded state) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_transitionController),
      child: ProjectWorkspace(
        selectedProject: state.selectedProject!,
        onBackToProjects: () {
          context.read<ProjectBloc>().add(const DeselectProject());
        },
      ),
    );
  }
}
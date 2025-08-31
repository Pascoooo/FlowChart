// ... (omitted imports)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../../../config/error/error_page.dart';
import '../animations/background_animation.dart';
import '../widgets/project_selector.dart';
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
            BlocListener<ProjectBloc, ProjectState>(
              listener: (context, state) {
                if (state is ProjectsLoaded && state.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error!),
                      backgroundColor: theme.colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                      return ErrorPage(
                        error: (state as ProjectError).message,
                        onRetry: () {
                          context.read<ProjectBloc>().add(const LoadProjects());
                        },
                      );
                    case ProjectsLoaded:
                      return _buildProjectsLoadedView(state as ProjectsLoaded, theme);
                    default:
                      return Center(
                        child: CupertinoActivityIndicator(
                          radius: 16,
                          color: theme.colorScheme.primary,
                        ),
                      );
                  }
                },
              ),
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

  Widget _buildProjectsLoadedView(ProjectsLoaded state, ThemeData theme) {
    debugPrint('=== DashboardPage DEBUG ===');
    debugPrint('selectedProject = ${state.selectedProject?.name ?? 'NULL'}');
    debugPrint('selectedProject ID = ${state.selectedProject?.projectId ?? 'NULL'}');
    debugPrint('projects count = ${state.projects.length}');
    debugPrint('========================');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutExpo,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isProjectSelector = child.key == const ValueKey('project-selector');

        if (isProjectSelector) {
          // Animazione per tornare alla dashboard (ProjectSelector)
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, -0.3), // Entra dall'alto
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.8, curve: Curves.easeOutExpo),
            )),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.85,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
              )),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                )),
                child: child,
              ),
            ),
          );
        } else {
          // Animazione per andare al workspace
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.2, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
            )),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.92,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.1, 1.0, curve: Curves.easeOutQuart),
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          );
        }
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
          debugPrint('DashboardPage: Selecting project ${project.name}');
          context.read<ProjectBloc>().add(SelectProject(project: project));
        },
        onCreateProject: (name) {
          debugPrint('DashboardPage: Creating project $name');
          context.read<ProjectBloc>().add(CreateProject(projectName: name));
        },
      ),
    );
  }
}
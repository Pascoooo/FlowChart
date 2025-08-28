// lib/screens/user_dashboard/views/project_workspace.dart (Fixed)
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../views/workarea.dart';
import '../widgets/sidebar.dart';
import '../widgets/topbar.dart';
import '../error/error_view.dart';

class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;
  final VoidCallback onBackToProjects;

  const ProjectWorkspace({
    super.key,
    required this.selectedProject,
    required this.onBackToProjects,
  });

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace>
    with TickerProviderStateMixin {
  late AnimationController _slideInController;
  late AnimationController _scaleController;
  late Animation<Offset> _sidebarSlideAnimation;
  late Animation<Offset> _topbarSlideAnimation;
  late Animation<Offset> _workareaSlideAnimation;
  late Animation<double> _workareaScaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _slideInController.forward();
  }

  void _initAnimations() {
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Sidebar slides in from left
    _sidebarSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    // Topbar slides down from top
    _topbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    // Workarea slides in from right with scale
    _workareaSlideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
    ));

    _workareaScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    // Start scale animation after slide in
    _slideInController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideInController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FileSystemBloc>(
      key: ValueKey('filesystem-${widget.selectedProject.projectId}'),
      create: (context) {
        final bloc = FileSystemBloc(
          projectRepository: context.read<ProjectBloc>().projectRepository,
        );
        bloc.add(RefreshFileSystem(projectId: widget.selectedProject.projectId));
        return bloc;
      },
      child: AnimatedBuilder(
        animation: _slideInController,
        builder: (context, child) {
          return Stack(
            children: [
              // Main workspace layout
              Row(
                children: [
                  // Sidebar with slide animation
                  SlideTransition(
                    position: _sidebarSlideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ProjectSidebar(
                        selectedProject: widget.selectedProject,
                      ),
                    ),
                  ),

                  // Main content area
                  Expanded(
                    child: Column(
                      children: [
                        // Topbar with slide animation
                        SlideTransition(
                          position: _topbarSlideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildTopbar(),
                          ),
                        ),

                        // Workarea with slide and scale animation
                        Expanded(
                          child: SlideTransition(
                            position: _workareaSlideAnimation,
                            child: ScaleTransition(
                              scale: _workareaScaleAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildWorkarea(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopbar() {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        if (state is FileSystemLoaded) {
          return TopBar(state: state, onBackToProjects: widget.onBackToProjects);
        }
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
          ),
          child: Center(
            child: Text(
              widget.selectedProject.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorkarea() {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, fileState) {
        if (fileState is FileSystemLoading) {
          return _buildLoadingWorkarea();
        }

        if (fileState is FileSystemError) {
          return ErrorView(message: fileState.message);
        }

        if (fileState is FileSystemLoaded) {
          final hasFiles = fileState.files.isNotEmpty;
          final hasSelectedFile = fileState.activeFileId != null;

          if (!hasFiles) {
            return _buildNoFilesView();
          }

          if (!hasSelectedFile) {
            return _buildSelectFileView();
          }

          return const WorkArea();
        }

        return _buildLoadingWorkarea();
      },
    );
  }

  Widget _buildLoadingWorkarea() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "Caricamento file...",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilesView() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.create_new_folder_rounded,
                size: 64,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Questo progetto non ha file",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Crea il tuo primo file dalla sidebar\nper cominciare a disegnare",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectFileView() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.secondary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.touch_app_rounded,
                size: 48,
                color: theme.colorScheme.secondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Seleziona un file",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Clicca su un file dalla sidebar per iniziare\na modificare i tuoi diagrammi",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
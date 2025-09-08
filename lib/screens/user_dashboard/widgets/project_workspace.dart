// lib/screens/user_dashboard/views/project_workspace.dart

import 'package:flowchart_thesis/screens/user_dashboard/widgets/topbar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/widgets/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:universal_html/html.dart' as html;
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';

import '../../../config/services/export_service.dart';
import '../views/workarea.dart';

class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;

  const ProjectWorkspace({super.key, required this.selectedProject});

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace>
    with TickerProviderStateMixin {
  final GlobalKey _workareaKey = GlobalKey();
  late AnimationController _slideInController;
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _sidebarSlideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    ));

    _topbarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    ));

    _workareaSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    ));

    _workareaScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    ));
  }

  @override
  void dispose() {
    _slideInController.dispose();
    super.dispose();
  }

  void _onEdit() async {
    final String path = Uri.base.toString().split('#')[0];
    final Uri url = Uri.parse('$path#/drawing-editor');

    html.WindowBase popup = html.window.open(url.toString(), 'editor', 'width=1200,height=800');
    if (popup.closed!) {
      throw("Popups blocked");
    }
  }

  String _getCurrentFileName(FileSystemLoaded state) {
    if (state.activeFileId != null && state.files.isNotEmpty) {
      final matchingFiles = state.files.where(
            (f) => f.fileId == state.activeFileId,
      );
      if (matchingFiles.isNotEmpty) {
        return matchingFiles.first.name.replaceAll(' ', '_').toLowerCase();
      }
    }
    return 'unichart_diagram';
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
      child: BlocListener<FileSystemBloc, FileSystemState>(
        listener: (context, state) {
          if (state is FileSystemError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: AnimatedBuilder(
          animation: _slideInController,
          builder: (context, child) {
            // Usa il context del builder che si trova all'interno del BlocProvider.
            final fileSystemBloc = context.watch<FileSystemBloc>();
            final state = fileSystemBloc.state;

            // Nuovo metodo per l'export che ha accesso al context corretto
            void handleExport() async {
              if (state is FileSystemLoaded && state.activeFileId != null) {
                try {
                  await ExportService.exportDirectlyToJpg(
                    context: context,
                    workareaKey: _workareaKey,
                    defaultFileName: _getCurrentFileName(state),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore nell\'esportazione: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              } else {
                // Optionally, show a message to the user that no file is selected.
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Seleziona un file prima di esportare.'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            }

            return Row(
              children: [
                SlideTransition(
                  position: _sidebarSlideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ProjectSidebar(
                      selectedProject: widget.selectedProject,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      right: 16.0,
                      bottom: 16.0,
                    ),
                    child: Column(
                      children: [
                        SlideTransition(
                          position: _topbarSlideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            // Passa la funzione di callback corretta
                            child: TopBar(
                              selectedProject: widget.selectedProject,
                              onEdit: _onEdit,
                              onExport: handleExport,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SlideTransition(
                            position: _workareaSlideAnimation,
                            child: ScaleTransition(
                              scale: _workareaScaleAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: _buildWorkarea(state),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkarea(FileSystemState state) {
    final hasActiveFile = state is FileSystemLoaded && state.activeFileId != null;

    return Stack(
      children: [
        if (!hasActiveFile)
          const Center(
            child: Text(
              'Seleziona o crea un file per iniziare a lavorare.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        Visibility(
          visible: hasActiveFile,
          maintainState: true,
          maintainAnimation: true,
          child: WorkArea(key: _workareaKey),
        ),
      ],
    );
  }
}
// lib/screens/user_dashboard/project_workspace.dart (Updated)
import 'package:flowchart_thesis/screens/user_dashboard/widgets/topbar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/widgets/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import 'dart:js' as js;

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

  // Metodo per gestire l'azione di modifica
  void _onEdit() {
    final baseUrl = Uri.base.toString().split('#')[0];
    js.context.callMethod('open', [
      '$baseUrl#/drawing-editor',
      '_blank',
      'width=1200,height=800,left=100,top=100,resizable=yes,scrollbars=yes,status=yes'
    ]);
  }

  // Metodo per gestire l'azione di esportazione
  void _handleExport() async {
    final state = BlocProvider.of<FileSystemBloc>(context).state;
    if (state is FileSystemLoaded) {
      try {
        await ExportService.exportDirectlyToJpg(
          context: context,
          workareaKey: WorkArea.workareaKey,
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
                            // Passa le funzioni di callback alla TopBar
                            child: TopBar(
                              selectedProject: widget.selectedProject,
                              onEdit: _onEdit,
                              onExport: _handleExport,
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
                                child: _buildWorkarea(),
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

  Widget _buildWorkarea() {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        if (state is FileSystemLoaded && state.activeFileId != null) {
          return const WorkArea();
        }
        return const Center(
          child: Text(
            'Seleziona o crea un file per iniziare a lavorare.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        );
      },
    );
  }
}
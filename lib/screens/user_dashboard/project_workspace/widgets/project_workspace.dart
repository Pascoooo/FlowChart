// lib/screens/user_dashboard/project_workspace/project_workspace.dart
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/topbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../config/services/dialog_service.dart';
import '../../../../config/services/banner_service.dart';
import '../../../../config/services/export_service.dart';

import '../views/workarea.dart';


class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;
  const ProjectWorkspace({super.key, required this.selectedProject});

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace> with TickerProviderStateMixin {
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


  String _getCurrentFileName(FileSystemLoaded state) {
    if (state.activeFileId != null && state.files.isNotEmpty) {
      final matchingFile = state.files.firstWhere(
            (f) => f.fileId == state.activeFileId,
        orElse: () => state.files.first,
      );
      return matchingFile.name.replaceAll(' ', '_').toLowerCase();
    }
    return 'unichart_diagram';
  }

  void _onEdit() async {
    final String path = Uri.base.toString().split('#')[0];
    final Uri url = Uri.parse('$path#/drawing-editor');

    html.WindowBase popup =
    html.window.open(url.toString(), 'editor', 'width=1200,height=800');
    if (popup.closed!) {
      throw ('Popups blocked');
    }
  }

  Future<void> _handleExport(BuildContext innerContext) async {
    final state = innerContext.read<FileSystemBloc>().state;

    if (state is FileSystemLoaded && state.activeFileId != null) {
      final fileName = _getCurrentFileName(state);
      await ExportService.exportWidgetToPng(
        context: context,
        key: _workareaKey,
        fileName: fileName,
      );
    } else {
      if (!mounted) return;
      await DialogService.showInfoDialog(
        innerContext,
        title: "Nessun File Selezionato",
        message: "Per favore, seleziona un file prima di esportare.",
        icon: Icons.warning_amber_rounded,
        iconColor: Theme.of(innerContext).colorScheme.error,
        closeText: "Capito",
      );
    }
  }


  @override
  Widget build(BuildContext outerContext) {
    return BlocProvider<FileSystemBloc>(
      key: ValueKey('filesystem-${widget.selectedProject.projectId}'),
      create: (context) => FileSystemBloc(
        projectRepository: context.read<ProjectBloc>().projectRepository,
      )..add(RefreshFileSystem(projectId: widget.selectedProject.projectId)),
      child: BlocListener<FileSystemBloc, FileSystemState>(
        listener: (context, state) {
          if (state is FileSystemError) {
            BannerService.showError(context, state.message);
          }
        },
        child: AnimatedBuilder(
          animation: _slideInController,
          builder: (innerContext, child) {
            return _WorkspaceLayout(
              sidebarSlideAnimation: _sidebarSlideAnimation,
              topbarSlideAnimation: _topbarSlideAnimation,
              workareaSlideAnimation: _workareaSlideAnimation,
              workareaScaleAnimation: _workareaScaleAnimation,
              fadeAnimation: _fadeAnimation,
              selectedProject: widget.selectedProject,
              workareaKey: _workareaKey,
              onEdit: _onEdit,
              onExport: () {
                _handleExport(innerContext);
              },
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceLayout extends StatelessWidget {
  final Animation<Offset> sidebarSlideAnimation;
  final Animation<Offset> topbarSlideAnimation;
  final Animation<Offset> workareaSlideAnimation;
  final Animation<double> workareaScaleAnimation;
  final Animation<double> fadeAnimation;
  final MyProject selectedProject;
  final GlobalKey workareaKey;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const _WorkspaceLayout({
    required this.sidebarSlideAnimation,
    required this.topbarSlideAnimation,
    required this.workareaSlideAnimation,
    required this.workareaScaleAnimation,
    required this.fadeAnimation,
    required this.selectedProject,
    required this.workareaKey,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SlideTransition(
          position: sidebarSlideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ProjectSidebar(selectedProject: selectedProject),
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
                  position: topbarSlideAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: TopBar(
                      selectedProject: selectedProject,
                      onEdit: onEdit,
                      onExport: onExport,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SlideTransition(
                    position: workareaSlideAnimation,
                    child: ScaleTransition(
                      scale: workareaScaleAnimation,
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: _WorkspaceContent(workareaKey: workareaKey),
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
  }
}


class _WorkspaceContent extends StatelessWidget {
  final GlobalKey workareaKey;

  const _WorkspaceContent({required this.workareaKey});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FileSystemBloc>().state;
    final hasActiveFile =
        state is FileSystemLoaded && state.activeFileId != null;

    return Stack(
      alignment: Alignment.center,
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
          child: WorkArea(repaintKey: workareaKey),
        ),
      ],
    );
  }
}
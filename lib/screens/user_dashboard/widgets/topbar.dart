// lib/screens/user_dashboard/widgets/topbar.dart (Updated)
import 'package:flowchart_thesis/screens/user_dashboard/widgets/topbar_buttons.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../config/services/export_service.dart';
import '../views/workarea.dart';

class TopBar extends StatefulWidget {
  final FileSystemLoaded state;
  final MyProject selectedProject;

  const TopBar({
    super.key,
    required this.state,
    required this.selectedProject,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildBreadcrumb(theme),
              const Spacer(),
              TopbarButtons(
                state: widget.state,
                onExport: _handleExport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExport() async {
    try {
      await ExportService.exportDirectlyToJpg(
        context: context,
        workareaKey: WorkArea.workareaKey,
        defaultFileName: _getCurrentFileName(),
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

  String _getCurrentFileName() {
    if (widget.state.activeFileId != null && widget.state.files.isNotEmpty) {
      final matchingFiles = widget.state.files.where(
              (f) => f.fileId == widget.state.activeFileId);
      if (matchingFiles.isNotEmpty) {
        return matchingFiles.first.name.replaceAll(' ', '_').toLowerCase();
      }
    }
    return 'unichart_diagram';
  }

  Widget _buildBreadcrumb(ThemeData theme) {
    final hasSelectedFile = widget.state.activeFileId != null;
    String currentFileName = "";

    if (hasSelectedFile && widget.state.files.isNotEmpty) {
      final matchingFiles = widget.state.files.where(
              (f) => f.fileId == widget.state.activeFileId
      );
      if (matchingFiles.isNotEmpty) {
        currentFileName = matchingFiles.first.name;
      }
    }

    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        // Unichart
        Text(
          "Unichart",
          style: textStyle?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        // Separator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.chevron_right,
            size: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        // Project name
        Flexible(
          child: Text(
            widget.selectedProject.name,
            style: textStyle?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // File name if active
        if (hasSelectedFile) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.chevron_right,
              size: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          Flexible(
            child: Text(
              currentFileName,
              style: textStyle?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
import 'package:file_repository/file_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';

class TopBar extends StatefulWidget {
  final MyProject selectedProject;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const TopBar({
    super.key,
    required this.selectedProject,
    required this.onEdit,
    required this.onExport,
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
    _slideController.forward();
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
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        final Widget child;
        if (state is FileSystemLoaded) {
          child = _AdvancedTopBar(
            state: state,
            selectedProjectName: widget.selectedProject.name,
            onEdit: widget.onEdit,
            onExport: widget.onExport,
          );
        } else {
          child = _SimpleTopBar(projectName: widget.selectedProject.name);
        }

        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: child,
          ),
        );
      },
    );
  }
}

/// TopBar mostrata durante il caricamento o in stati non "Loaded".
class _SimpleTopBar extends StatelessWidget {
  final String projectName;
  const _SimpleTopBar({required this.projectName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open_rounded,
              color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  projectName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "Caricamento...",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// TopBar mostrata quando il file system è caricato.
class _AdvancedTopBar extends StatelessWidget {
  final FileSystemLoaded state;
  final String selectedProjectName;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const _AdvancedTopBar({
    required this.state,
    required this.selectedProjectName,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
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
          Expanded(
            child: _Breadcrumb(
              state: state,
              selectedProjectName: selectedProjectName,
            ),
          ),
          _ActionButtons(
            hasSelectedFile: state.activeFileId != null,
            onEdit: onEdit,
            onExport: onExport,
          ),
        ],
      ),
    );
  }
}

/// Widget per la visualizzazione del breadcrumb.
class _Breadcrumb extends StatelessWidget {
  final FileSystemLoaded state;
  final String selectedProjectName;

  const _Breadcrumb({required this.state, required this.selectedProjectName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelectedFile = state.activeFileId != null;
    String currentFileName = "";

    if (hasSelectedFile && state.files.isNotEmpty) {
      final matchingFile = state.files.firstWhere(
        (file) => file.fileId == state.activeFileId,
        orElse: () => const MyFile(fileId: '', name: 'Unknown', content: '')
      );
      currentFileName = matchingFile.name;
        }

    final textStyle =
    theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
      ),
    );

    return Row(
      children: [
        Icon(Icons.auto_awesome,
            size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text("Unichart",
            style: textStyle?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6))),
        separator,
        Flexible(
          child: Text(
            selectedProjectName,
            style: textStyle?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasSelectedFile) ...[
          separator,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              currentFileName,
              style: textStyle?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (!hasSelectedFile && state.files.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${state.files.length} file${state.files.length != 1 ? 's' : ''}",
              style: textStyle?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget per i pulsanti di azione della TopBar.
class _ActionButtons extends StatelessWidget {
  final bool hasSelectedFile;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const _ActionButtons({
    required this.hasSelectedFile,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSelectedFile) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
        const SizedBox(width: 8),
        IconButton(
            icon: const Icon(Icons.download, size: 20), onPressed: onExport),
      ],
    );
  }
}
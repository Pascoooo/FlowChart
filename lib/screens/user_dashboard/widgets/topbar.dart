// lib/screens/user_dashboard/widgets/topbar.dart
import 'package:flowchart_thesis/screens/user_dashboard/widgets/topbar_buttons.dart';
import 'package:flutter/material.dart';
import '../../../blocs/file_bloc/file_system_state.dart';

class TopBar extends StatefulWidget {
  final FileSystemLoaded state;

  const TopBar({super.key, required this.state});

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
            color: theme.colorScheme.surface.withOpacity(0.9),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildBreadcrumb(theme),
              const Spacer(),
              TopbarButtons(state: widget.state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(ThemeData theme) {
    final hasSelectedFile = widget.state.activeFileId != null;
    String currentPage = hasSelectedFile ? "File" : "Progetto";

    if (hasSelectedFile && widget.state.files.isNotEmpty) {
      final matchingFiles = widget.state.files.where(
              (f) => f.fileId == widget.state.activeFileId
      );
      if (matchingFiles.isNotEmpty) {
        currentPage = matchingFiles.first.name;
      }
    }

    final titleStyle = theme.textTheme.titleMedium ?? const TextStyle();
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App name
        Text(
          "Unichart",
          style: titleStyle.copyWith(
            color: onSurfaceColor.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),

        // Separator
        Icon(
          Icons.chevron_right,
          size: 12,
          color: onSurfaceColor.withOpacity(0.4),
        ),
        const SizedBox(width: 8),

        // Current page/file
        Text(
          currentPage,
          style: titleStyle.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Status indicator
        if (hasSelectedFile) ...[
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
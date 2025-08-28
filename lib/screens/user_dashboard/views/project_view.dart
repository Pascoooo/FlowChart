import 'package:flowchart_thesis/screens/user_dashboard/views/workarea.dart';
import 'package:flutter/material.dart';
import '../../../blocs/file_bloc/file_system_state.dart';

class ProjectView extends StatefulWidget {
  final FileSystemLoaded state;

  const ProjectView({
    super.key,
    required this.state,
  });

  @override
  State<ProjectView> createState() => _ProjectViewState();
}

class _ProjectViewState extends State<ProjectView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: Opacity(
              opacity: value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.surface.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      blurRadius: 60,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Expanded(
                      child: WorkArea(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
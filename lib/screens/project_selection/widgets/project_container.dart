import 'package:flowchart_thesis/screens/project_selection/widgets/project_carousel.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';

class ProjectContainer extends StatelessWidget {
  final List<MyProject> projects;
  final void Function(MyProject) onProjectSelected;
  final void Function(String) onProjectDeleted;
  final void Function(String, String) onProjectRenamed;

  const ProjectContainer({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onProjectDeleted,
    required this.onProjectRenamed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double containerheight = 400;
    const double containerWidth = 800;

    return Container(
      width: containerWidth,
      height: containerheight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            theme.colorScheme.surface.withOpacity(0.8),
          ],
        ),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Text(
              "I tuoi progetti",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: projects.isNotEmpty
                ? ProjectCarousel(
              projects: projects,
              onProjectSelected: onProjectSelected,
              onProjectDeleted: (projectId) => onProjectDeleted(projectId),
              onProjectRenamed: (projectId, newName) => onProjectRenamed(projectId, newName),
            )
                : const EmptyState(),
          ),
        ],
      ),
    );
  }
}


class EmptyState extends StatelessWidget {
  const EmptyState({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(FontAwesomeIcons.folderOpen, size: 32, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
        const SizedBox(height: 16),
        Text("Nessun progetto trovato", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          "Inizia creando il tuo primo progetto",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavigationButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';

import 'card_pop_menu.dart';

class ProjectCard extends StatelessWidget {
  final MyProject project;
  final List<MyProject> projects;
  final VoidCallback onTap;
  final VoidCallback onDeleted;
  final Function(String) onRenamed;

  const ProjectCard({
    super.key,
    required this.project,
    required this.projects,
    required this.onTap,
    required this.onDeleted,
    required this.onRenamed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      height: 180,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              theme.colorScheme.surface.withOpacity(0.9),
            ],
          ),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            theme.colorScheme.primary.withOpacity(0.2),
                            theme.colorScheme.primary.withOpacity(0.1),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(FontAwesomeIcons.folder, size: 20, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        project.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: CardPopupMenu(
                    project: project,
                    projects: projects,
                    onDeleted: onDeleted,
                    onRenamed: onRenamed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

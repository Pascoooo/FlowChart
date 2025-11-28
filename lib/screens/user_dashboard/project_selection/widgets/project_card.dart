/// Individual project card widget displaying project name and icon with hover effects.
/// Includes contextual popup menu for project actions (rename, delete).
import 'package:fluent_ui/fluent_ui.dart';
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

  /// Builds project card with gradient background, folder icon, and popup menu.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return SizedBox(
      width: 220,
      height: 200,
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor.withOpacity(0.8),
                  theme.cardColor,
                ],
              ),
              border: Border.all(color: theme.inactiveColor.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                            theme.accentColor.withOpacity(0.2),
                            theme.accentColor.withOpacity(0.1),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.folder,
                          size: 24,
                          color: theme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        project.name,
                        style: theme.typography.bodyStrong?.copyWith(
                          color: theme.typography.body?.color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  height: 32,
                  width: 32,
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
          );
        },
      ),
    );
  }
}

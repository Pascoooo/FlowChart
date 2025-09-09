import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../config/constants/theme_switch.dart';
import '../../../config/services/dialog_service.dart';
import '../widgets/project_container.dart';
import '../widgets/welcome_header.dart';

class ProjectSelector extends StatelessWidget {
  final List<MyProject> projects;
  final Function(MyProject) onProjectSelected;
  final Function(String) onCreateProject;

  const ProjectSelector({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onCreateProject,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> showCreateProjectDialog() async {
      final String? projectName = await DialogService.showInputDialog(
        context,
        title: "Nuovo Progetto",
        message: "Dai un nome al tuo progetto per iniziare",
        hintText: "es. Il mio diagramma di flusso",
        confirmText: "Crea Progetto",
        cancelText: "Annulla",
        validator: (v) => ValidationUtils.validateProjectName(v, projects),
      );

      if (projectName != null) {
        onCreateProject(projectName);
      }
    }

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            primary: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const WelcomeHeader(),
                const SizedBox(height: 48),
                EnhancedProjectContainer(
                  projects: projects,
                  onProjectSelected: onProjectSelected,
                  onProjectDeleted: (projectId) {
                    context.read<ProjectBloc>().add(DeleteProject(projectId: projectId));
                  },
                  onProjectRenamed: (projectId, newName) {
                    context.read<ProjectBloc>().add(RenameProject(projectId: projectId, newName: newName));
                  },
                ),
                const SizedBox(height: 32),
                CreateProjectButton(
                  projectCount: projects.length,
                  onPressed: showCreateProjectDialog,
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 24,
          right: 24,
          child: ProfileMenu(),
        ),
        const Positioned(
          bottom: 24,
          right: 24,
          child: ThemeToggleButton(),
        ),
      ],
    );
  }
}


class CreateProjectButton extends StatelessWidget {
  final int projectCount;
  final VoidCallback onPressed;
  const CreateProjectButton({super.key, required this.projectCount, required this.onPressed});


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.plus, size: 16, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(
                  projectCount == 0 ? "Crea il tuo primo progetto" : "Nuovo Progetto",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                child: Icon(
                  theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  key: ValueKey(theme.brightness),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            ),
          ),
        );
      },
    );
  }
}
/// Project selection screen displaying all user projects in a sortable grid.
/// Allows creating new projects, selecting existing ones, and managing project actions.
/// Includes welcome header, profile menu, and theme toggle button.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:provider/provider.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/validation_service.dart';
import '../../../../config/widgets/buttons.dart';
import '../widgets/profile_picture.dart';
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

  /// Builds project selector UI with sorted projects, welcome header, and action buttons.
  /// Projects are sorted by most recently updated first for optimal user experience.
  @override
  Widget build(BuildContext context) {
    final sortedProjects = List<MyProject>.from(projects)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    /// Shows dialog for creating a new project with name validation.
    Future<void> showCreateProjectDialog() async {
      final String? projectName = await AppDialogs.showInputDialog(
        context,
        title: "Nuovo Progetto",
        message: "Dai un nome al tuo progetto per iniziare",
        hintText: "es. Flowchart",
        confirmText: "Crea Progetto",
        cancelText: "Annulla",
        inputLabel: "Nome Progetto",
        validator: (v) => ValidationService.validateProjectName(v, projects),
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
                ProjectContainer(
                  projects: sortedProjects,
                  onProjectSelected: onProjectSelected,
                  onProjectDeleted: (projectId) {
                    context
                        .read<ProjectBloc>()
                        .add(DeleteProject(projectId: projectId));
                  },
                  onProjectRenamed: (projectId, newName) {
                    context.read<ProjectBloc>().add(
                        RenameProject(projectId: projectId, newName: newName));
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
          right: 20,
          child: ProfileMenu(),
        ),
        const Positioned(
          height: 48,
          width: 48,
          bottom: 20,
          right: 20,
          child: ThemeToggleButton(),
        ),
      ],
    );
  }
}

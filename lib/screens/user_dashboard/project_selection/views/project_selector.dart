import 'package:flowchart_thesis/config/services/validation_service.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import 'package:provider/provider.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
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

  @override
  Widget build(BuildContext context) {
    Future<void> showCreateProjectDialog() async {
      final String? projectName = await AppDialogs.showInputDialog(
        context,
        title: "Nuovo Progetto",
        message: "Dai un nome al tuo progetto per iniziare",
        hintText: "es. Flowchart",
        confirmText: "Crea Progetto",
        cancelText: "Annulla",
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


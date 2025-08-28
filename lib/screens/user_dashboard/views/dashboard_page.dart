// lib/screens/user_dashboard/views/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../animations/background_animation.dart';
import '../widgets/sidebar.dart';
import '../widgets/topbar.dart';
import '../error/error_view.dart';
import 'workarea.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    context.read<ProjectBloc>().add(const LoadProjects());
  }

  void _initAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.98),
              theme.colorScheme.surfaceVariant.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            const AnimatedBackground(),
            BlocBuilder<ProjectBloc, ProjectState>(
              builder: (context, projectState) {
                if (projectState is ProjectLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (projectState is ProjectError) {
                  return ErrorView(message: projectState.message);
                }

                if (projectState is ProjectsLoaded) {
                  final hasProjects = projectState.projects.isNotEmpty;
                  final selectedProject = projectState.selectedProject;

                  // Caso 1: Nessun progetto esistente
                  if (!hasProjects) {
                    return _buildNoProjectsView();
                  }

                  // Caso 2: Progetti esistenti ma nessuno selezionato
                  if (selectedProject == null) {
                    return _buildProjectListView(projectState.projects);
                  }

                  // Caso 3: Un progetto è selezionato (mostra UI completa)
                  return BlocProvider<FileSystemBloc>(
                    key: ValueKey(selectedProject.projectId),
                    create: (context) {
                      final bloc = FileSystemBloc(
                          projectRepository:
                          context.read<ProjectBloc>().projectRepository);
                      bloc.add(RefreshFileSystem(projectId: selectedProject.projectId));
                      return bloc;
                    },
                    child: Row(
                      children: [
                        ProjectSidebar(state: projectState), // Sidebar visibile
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _contentAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(30 * (1 - _contentAnimation.value), 0),
                                child: Opacity(
                                  opacity: _contentAnimation.value,
                                  child: _buildFileContent(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Stato sconosciuto
                return const Center(child: Text("Stato sconosciuto"));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProjectsView() {
    final theme = Theme.of(context);
    final isCreating = context.watch<ProjectBloc>().state is ProjectLoading;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.create_new_folder_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Benvenuto in Unichart",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Inizia creando il tuo primo progetto per\ncominciare a disegnare diagrammi",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: isCreating
                ? null
                : () {
              _showCreateProjectDialog(context);
            },
            icon: isCreating
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.add),
            label: Text(
              isCreating ? "Creazione in corso..." : "Crea il tuo primo progetto",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectListView(List<MyProject> projects) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "Seleziona un progetto",
            style: theme.textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                title: Text(project.name),
                onTap: () {
                  context.read<ProjectBloc>().add(SelectProject(project: project));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileContent() {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, fileState) {
        if (fileState is FileSystemLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (fileState is FileSystemError) {
          return ErrorView(message: fileState.message);
        }
        if (fileState is FileSystemLoaded) {
          final hasFiles = fileState.files.isNotEmpty;
          final hasSelectedFile = fileState.activeFileId != null;

          if (!hasFiles) {
            // Se il progetto non ha file, mostra la vista per crearne uno.
            return _buildNoFilesView();
          }

          if (!hasSelectedFile) {
            // Se ci sono file ma nessuno è selezionato, mostra la vista "seleziona un file"
            return _buildSelectFileView();
          }
          // Altrimenti, mostra l'area di lavoro
          return const WorkArea();
        }
        return const Center(child: Text("Stato file sconosciuto"));
      },
    );
  }

  Widget _buildNoFilesView() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.create_new_folder_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Questo progetto non ha file",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Crea il tuo primo file per cominciare a disegnare",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectFileView() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 48,
              color: theme.colorScheme.secondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Seleziona un file",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Clicca su un file dalla sidebar per iniziare\na modificare i tuoi diagrammi",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Crea un nuovo progetto'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Nome del progetto'),
            autofocus: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                context.read<ProjectBloc>().add(CreateProject(projectName: value));
                Navigator.of(dialogContext).pop();
              }
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Crea'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  context.read<ProjectBloc>().add(CreateProject(projectName: nameController.text));
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
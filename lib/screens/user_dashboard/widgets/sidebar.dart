// lib/screens/user_dashboard/widgets/sidebar.dart
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_thesis/config/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_state.dart';

class ProjectSidebar extends StatefulWidget {
  final ProjectState state;

  const ProjectSidebar({
    super.key,
    required this.state,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _shimmerController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _floatingController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // BlocListener è stato spostato in _buildFileSystemView per una gestione più locale
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: 320,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withOpacity(0.95),
            theme.colorScheme.surfaceVariant.withOpacity(0.1),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          _buildDivider(theme),
          _buildCreateFileButton(theme), // Modificato in "file"
          _buildDivider(theme),
          Expanded(child: _buildFileSystemView(theme)),
          _buildMainDivider(theme),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Unichart",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "AI-Powered Diagrams",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFileButton(ThemeData theme) {
    final selectedProject = (widget.state as ProjectsLoaded).selectedProject;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ModernMenuItem(
        icon: FontAwesomeIcons.plus,
        title: "Nuovo File",
        onTap: selectedProject != null
            ? () => _showCreateFileDialog(context, selectedProject.projectId)
            : () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seleziona un progetto per creare un nuovo file.'),
            ),
          );
        },
        isPrimaryAction: true,
      ),
    );
  }

  // Corretta la logica per usare il FileSystemBloc
  Widget _buildFileSystemView(ThemeData theme) {
    return BlocConsumer<FileSystemBloc, FileSystemState>(
      listener: (context, state) {
        if (state is FileSystemLoaded) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: theme.colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else if (state is FileSystemError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      builder: (context, fileState) {
        if (fileState is FileSystemLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  "Caricamento file...",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }
        if (fileState is FileSystemError) {
          return _buildErrorView(theme, fileState.message);
        }
        if (fileState is FileSystemLoaded) {
          final files = fileState.files;
          if (files.isEmpty) {
            return _buildEmptyFilesView(theme); // Modificato in "files"
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final isSelected = file.fileId == fileState.activeFileId;
              return _buildFileTile(theme, file, isSelected);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorView(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Errore',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilesView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun File',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inizia creando il tuo\nprimo file',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTile(ThemeData theme, MyFile file, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Invia l'evento per aprire un file
            //context.read<FileSystemBloc>().add(OpenFile(fileId: file.fileId, projectId: '', fileName: ''));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isSelected
                  ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.15),
                  theme.colorScheme.primary.withOpacity(0.08),
                ],
              )
                  : null,
              border: isSelected
                  ? Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 1,
              )
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    size: 16,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateFileDialog(BuildContext context, String projectId) async {
    final nameController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuovo File'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nome file'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              context.read<FileSystemBloc>().add(CreateNewFile(fileName: value, projectId: projectId));
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
                context.read<FileSystemBloc>().add(CreateNewFile(fileName: nameController.text, projectId: projectId));
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            theme.colorScheme.outline.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildMainDivider(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.colorScheme.outline.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.more_horiz,
              size: 16,
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.outline.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ModernMenuItem(
            icon: FontAwesomeIcons.gear,
            title: "Impostazioni",
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 8),
          ModernMenuItem(
            icon: FontAwesomeIcons.rightFromBracket,
            title: "Logout",
            onTap: () {
              context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

}
// lib/screens/user_dashboard/widgets/sidebar.dart (Updated)
import 'package:file_repository/file_repository.dart';
import 'package:flowchart_thesis/config/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../config/router/app_router.dart';
import '../../../config/services/dialog_service.dart';

class ProjectSidebar extends StatefulWidget {
  final MyProject selectedProject;

  const ProjectSidebar({
    super.key,
    required this.selectedProject,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
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

    _floatingAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _floatingController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          _buildDivider(theme),
          Expanded(child: _buildFileSystemView(theme)),
          // Nuovo file button alla fine della lista files
          _buildCreateFileButton(theme),
          // Separatore principale prima dei bottoni in basso
          _buildMainDivider(theme),
          _buildBottomActions(theme),
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
          // Bottone per tornare ai progetti usando il BLoC
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Usa il BLoC per tornare ai progetti - NO animazioni manuali
                context.read<ProjectBloc>().add(const DeselectProject());
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      height: 32, // Altezza fissa per il separatore
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.colorScheme.outline.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
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
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.outline.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceVariant.withOpacity(0.3),
            theme.colorScheme.surfaceVariant.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ModernMenuItem(
            icon: FontAwesomeIcons.gear,
            title: "Impostazioni",
            onTap: () => AppRouter.goToSettings(context),
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

  Widget _buildFileSystemView(ThemeData theme) {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, fileState) {
        if (fileState is FileSystemLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (fileState is FileSystemError) {
          return Center(child: Text(fileState.message));
        }

        if (fileState is FileSystemLoaded) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: fileState.files.length,
            itemBuilder: (context, index) {
              final file = fileState.files[index];
              final isSelected = file.fileId == fileState.activeFileId;

              return _buildFileItem(theme, file, isSelected, context);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFileItem(ThemeData theme, MyFile file, bool isSelected, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.insert_drive_file,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(
          file.name,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameFileDialog(context, file);
            } else if (value == 'delete') {
              _showDeleteConfirmationDialog(context, file);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rinomina'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Elimina'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          if (!isSelected) {
            context.read<FileSystemBloc>().add(OpenFile(fileId: file.fileId, projectId: widget.selectedProject.projectId, fileName: file.name) );
          }
        },
      ),
    );
  }

  void _showRenameFileDialog(BuildContext context, MyFile file) {
    final nameController = TextEditingController(text: file.name);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.95),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.2),
                        theme.colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Rinomina File',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nuovo nome file',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty && value.trim() != file.name) {
                      context.read<FileSystemBloc>().add(
                        RenameFile(
                          fileId: file.fileId,
                          newName: value.trim(), projectId: widget.selectedProject.projectId
                        ),
                      );
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Annulla',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            final newName = nameController.text.trim();
                            if (newName.isNotEmpty && newName != file.name) {
                              context.read<FileSystemBloc>().add(
                                RenameFile(
                                  fileId: file.fileId,
                                  newName: newName, projectId: widget.selectedProject.projectId
                                ),
                              );
                              Navigator.of(dialogContext).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Rinomina',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, MyFile file) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.95),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.error.withOpacity(0.2),
                        theme.colorScheme.error.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Elimina File',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sei sicuro di voler eliminare "${file.name}"? Questa azione è irreversibile.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Annulla',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            context.read<FileSystemBloc>().add(
                              DeleteFile(
                                fileId: file.fileId, projectId: widget.selectedProject.projectId
                              ),
                            );
                            Navigator.of(dialogContext).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Elimina',
                            style: TextStyle(
                              color: theme.colorScheme.onError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateFileButton(ThemeData theme) {
    final projectId = widget.selectedProject.projectId;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        onTap: () => _showCreateFileDialog(context, projectId),
        leading: Icon(
          Icons.add_circle_outline,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          "Nuovo File",
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  void _showCreateFileDialog(BuildContext context, String projectId) async {
    final String? fileName = await DialogService.showInputDialog(
      context,
      title: "Crea Nuovo File",
      message: "Dai un nome al tuo nuovo file",
      hintText: "es. Diagramma Principale",
      confirmText: "Crea File",
    );

    if (fileName != null && fileName.isNotEmpty) {
      context.read<FileSystemBloc>().add(
        CreateNewFile(
          projectId: projectId,
          fileName: fileName,
        ),
      );
    }
  }
}
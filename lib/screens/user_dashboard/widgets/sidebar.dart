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
      child: Column(
        children: [
          // Primo Container: Contiene la lista dei file ed è espanso per occupare lo spazio rimanente.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                  _buildCreateFileButton(theme),
                ],
              ),
            ),
          ),
          // Spazio tra i due riquadri
          const SizedBox(height: 16),
          // Secondo Container: Contiene solo i bottoni e ha altezza fissa.
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
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
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
          const SizedBox(width: 16),
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

  Widget _buildBottomActions(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          ModernMenuItem(
            icon: FontAwesomeIcons.gear,
            title: "Impostazioni",
            onTap: () => AppRouter.goToSettings(context),
          ),
          const SizedBox(height: 8),
          ModernMenuItem(
            icon: FontAwesomeIcons.rightFromBracket,
            title: "Logout",
            onTap: _confirmLogout,
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

  void _showRenameFileDialog(BuildContext context, MyFile file) async {
    if (file.name == 'main') {
      await DialogService.showInfoDialog(
        context,
        title: "Azione Non Permessa",
        content: const Text('Il "main" non può essere rinominato.'),
        icon: Icons.info_outline,
      );
      return;
    }
    final String? newName = await DialogService.showInputDialog(
      context,
      title: "Rinomina File",
      initialValue: file.name,
      hintText: "es. Diagramma Riveduto",
      confirmText: "Rinomina",
    );

    if (newName != null && newName.trim().isNotEmpty && newName.trim() != file.name) {
      context.read<FileSystemBloc>().add(
        RenameFile(
          fileId: file.fileId,
          newName: newName.trim(),
          projectId: widget.selectedProject.projectId,
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, MyFile file) async {
    if (file.name == 'main') {
      await DialogService.showInfoDialog(
        context,
        title: "Azione Non Permessa",
        content: const Text('Il file "main" non può essere eliminato.'),
        icon: Icons.info_outline,
      );
      return;
    }
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: "Elimina File",
      message: 'Sei sicuro di voler eliminare "${file.name}"? Questa azione è irreversibile.',
      confirmText: "Elimina",
    );

    if (confirmed == true) {
      context.read<FileSystemBloc>().add(
        DeleteFile(
          fileId: file.fileId,
          projectId: widget.selectedProject.projectId,
        ),
      );
    }
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

  void _confirmLogout() async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Logout',
      message: 'Sei sicuro di voler effettuare il logout?',
      confirmText: 'Logout',
      cancelText: 'Annulla',
    );

    if (confirmed == true) {
      if (!mounted) return;
      context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
    }
  }
}
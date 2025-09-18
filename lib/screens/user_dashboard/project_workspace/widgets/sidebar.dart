import 'package:file_repository/file_repository.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:flowchart_thesis/config/widgets/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/router/app_router.dart';
import '../../../../config/services/dialog_service.dart';

class ProjectSidebar extends StatefulWidget {
  final MyProject selectedProject;

  const ProjectSidebar({
    super.key,
    required this.selectedProject,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
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
                  const _SidebarHeader(),
                  _buildDivider(theme),
                  Expanded(
                    child: _FileSystemView(
                      projectId: widget.selectedProject.projectId,
                    ),
                  ),
                  CreateFileButton(projectId: widget.selectedProject.projectId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const BottomActions(),
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
}

/// Header della Sidebar che contiene il pulsante per tornare alla dashboard.
class _SidebarHeader extends StatefulWidget {
  const _SidebarHeader();

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
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
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              /// CORREZIONE: Invia l'evento LeaveProject per un'uscita sicura.
              onTap: () => context.read<ProjectBloc>().add(const LeaveProject()),
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
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _floatingAnimation.value),
              child: child,
            ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                ),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _FileSystemView extends StatelessWidget {
  final String projectId;
  const _FileSystemView({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        if (state is FileSystemLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is FileSystemError) {
          return Center(child: Text(state.message));
        }
        if (state is FileSystemLoaded) {
          if (state.files.isEmpty) {
            return const Center(
                child: Text("Nessun file presente.\nCreane uno per iniziare!",
                    textAlign: TextAlign.center));
          }
          final orderedFiles = List<MyFile>.from(state.files);
          orderedFiles.sort((a, b) {
            if (a.name == 'main') return -1;
            if (b.name == 'main') return 1;
            return a.name.compareTo(b.name);
          });

          return Scrollbar(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: orderedFiles.length,
              itemBuilder: (context, index) {
                final file = orderedFiles[index];
                return FileListItem(
                  file: file,
                  isSelected: file.fileId == state.activeFileId,
                  projectId: projectId,
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Elemento della lista che rappresenta un singolo file.
class FileListItem extends StatelessWidget {
  final MyFile file;
  final bool isSelected;
  final String projectId;

  const FileListItem({super.key,
    required this.file,
    required this.isSelected,
    required this.projectId,
  });

  void _showRenameFileDialog(BuildContext context, MyFile file) async {
    final newName = await DialogService.showInputDialog(context,
        initialValue: file.name,
        title: "Rinomina file",
        message: "Inserisci un nuovo nome per il file",
        hintText: "es. File",
        confirmText: "Rinomina",
        cancelText: "Annulla",
        validator: (v) {
          final value = (v ?? "").trim();
          if (value.isEmpty) return 'Il nome non può essere vuoto';
          final state = context.read<FileSystemBloc>().state;
          if (state is FileSystemLoaded) {
            final exists = state.files.any(
                  (f) =>
              f.name.toLowerCase() == value.toLowerCase() &&
                  f.fileId != file.fileId,
            );
            if (exists) return 'Nome già in uso';
          }
          if (value.length > 20) {
            return 'Nome troppo lungo! (max 20 caratteri)';
          }
          return null;
        });

    if (newName == null) return;
    final value = newName.trim();
    if (value.isEmpty) return;

    context.read<FileSystemBloc>().add(
      RenameFile(
        fileId: file.fileId,
        projectId: projectId,
        newName: newName.toLowerCase(),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, MyFile file) async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: "Elimina File",
      message:
      'Sei sicuro di voler eliminare "${file.name}"? Questa azione è irreversibile.',
      confirmText: "Elimina",
    );

    if (confirmed == true) {
      context.read<FileSystemBloc>().add(
        DeleteFile(
          fileId: file.fileId,
          projectId: projectId,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMain = file.name == 'main';

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
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    file.name,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isMain)
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
            trailing: isMain
                ? null
                : PopupMenuButton<String>(
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
                context.read<FileSystemBloc>().add(
                  OpenFile(
                    fileId: file.fileId,
                    projectId: projectId,
                    fileName: file.name,
                  ),
                );
              }
            }));
  }
}

/// Pulsante per creare un nuovo file.
class CreateFileButton extends StatelessWidget {
  final String projectId;

  const CreateFileButton({super.key, required this.projectId});

  void _showCreateFileDialog(BuildContext context, String projectId) async {
    final newName = await DialogService.showInputDialog(context,
        title: "Crea file",
        message: "Inserisci un nuovo nome per il file",
        hintText: "es. File",
        confirmText: "Crea",
        cancelText: "Annulla",
        validator: (v) {
          final value = (v ?? "").trim();
          if (value.isEmpty) return 'Il nome non può essere vuoto';
          final state = context.read<FileSystemBloc>().state;
          if (state is FileSystemLoaded) {
            final exists = state.files.any(
                  (f) => f.name.toLowerCase() == value.toLowerCase(),
            );
            if (exists) return 'Nome già in uso';
          }
          if (value.length > 20) {
            return 'Nome troppo lungo! (max 20 caratteri)';
          }
          return null;
        });

    if (newName == null) return;
    final value = newName.trim();
    if (value.isEmpty) return;

    context
        .read<FileSystemBloc>()
        .add(CreateNewFile(projectId: projectId, fileName: newName.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        leading:
        Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
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
}

/// Azioni in fondo alla sidebar.
class BottomActions extends StatelessWidget {
  const BottomActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
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
            iconWidget:  Icon(Icons.settings_rounded, color: theme.colorScheme.onSurfaceVariant),
            onTap: () => AppRouter.goToSettings(context),
            title: "Impostazioni",
          ),
          ModernMenuItem(
            iconWidget: AnimatedThemeIcon(isDark: isDark),
            title: "Cambia Tema",
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        ],
      ),
    );
  }
}

/// Icona animata per il cambio tema.
class AnimatedThemeIcon extends StatelessWidget {
  final bool isDark;
  const AnimatedThemeIcon({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1.0).animate(animation),
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        key: ValueKey(isDark),
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
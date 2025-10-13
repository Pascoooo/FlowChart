import 'package:file_repository/file_repository.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/router/app_router.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/dialog_service/node_dialogs/create_function_dialog.dart';

class ProjectSidebar extends StatefulWidget {
  final MyProject selectedProject;
  final bool isReadOnly;

  const ProjectSidebar({
    super.key,
    required this.selectedProject,
    this.isReadOnly = false,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border:
                Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  const _SidebarHeader(),
                  _buildDivider(theme),
                  Expanded(
                    child: _FileSystemView(
                      projectId: widget.selectedProject.projectId,
                      isReadOnly: widget.isReadOnly,
                    ),
                  ),
                  if (!widget.isReadOnly)
                    CreateFileButton(
                        projectId: widget.selectedProject.projectId),
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

  Widget _buildDivider(FluentThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            theme.inactiveColor.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Header della Sidebar.
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
    final theme = FluentTheme.of(context);
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              context.read<ProjectBloc>().add(const LeaveProject());
            },
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              backgroundColor: WidgetStatePropertyAll(
                theme.accentColor.lighter.withValues(alpha: 0.1),
              ),
            ),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: theme.accentColor,
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
                    theme.accentColor,
                    theme.accentColor.lighter,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                FontAwesomeIcons.diagramProject,
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
                  style: theme.typography.title
                      ?.copyWith(fontWeight: FontWeight.bold),
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
    final bool isReadOnly;
    const _FileSystemView({required this.projectId, this.isReadOnly = false});

    @override
    Widget build(BuildContext context) {
      return BlocBuilder<FileSystemBloc, FileSystemState>(
        builder: (context, state) {
          if (state is FileSystemLoading) {
            return const Center(child: ProgressRing());
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
                primary: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: orderedFiles.length,
                itemBuilder: (context, index) {
                  final file = orderedFiles[index];
                  return FileListItem(
                    file: file,
                    isSelected: file.fileId == state.activeFileId,
                    projectId: projectId,
                    isReadOnly: isReadOnly,
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
  final bool isReadOnly;

  const FileListItem({
    super.key,
    required this.file,
    required this.isSelected,
    required this.projectId,
    this.isReadOnly = false,
  });

  void _showRenameFileDialog(BuildContext context, MyFile file) async {
    // Logic unchanged
    final newName = await AppDialogs.showInputDialog(
        context,
        initialValue: file.name,
        title: "Rinomina file",
        message: "Inserisci un nuovo nome per il file",
        inputLabel: "Nome File",
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
    // Logic unchanged
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: "Elimina File",
      message:
      'Sei sicuro di voler eliminare "${file.name}"? Questa azione è irreversibile.',
      confirmText: "Elimina",
      isDestructive: true,
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
    final theme = FluentTheme.of(context);
    final isMain = file.name == 'main';
    final flyoutController = FlyoutController();

    // Salva il contesto esterno per usarlo dopo la chiusura del flyout
    final outerContext = context;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.accentColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.3)
              : theme.inactiveColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.insert_drive_file,
          color: isSelected
              ? theme.accentColor
              : theme.typography.body?.color?.withValues(alpha: 0.6),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                file.name,
                style: (theme.typography.body ?? const TextStyle()).copyWith(
                  color: isSelected
                      ? theme.accentColor.darker
                      : theme.typography.body?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        trailing: isReadOnly
            ? (isMain
                ? Icon(
                    Icons.star,
                    size: 16,
                    color: theme.accentColor.withValues(alpha: 0.8),
                  )
                : null)
            : (isMain
                ? Icon(
                    Icons.star,
                    size: 16,
                    color: theme.accentColor.withValues(alpha: 0.8),
                  )
                : FlyoutTarget(
                    controller: flyoutController,
                    child: IconButton(
                      icon: Icon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 16,
                        color: theme.typography.body?.color?.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        flyoutController.showFlyout(
                          builder: (flyoutContext) => MenuFlyout(
                            items: [
                              MenuFlyoutItem(
                                leading: const Icon(Icons.edit),
                                text: const Text('Rinomina'),
                                onPressed: () {
                                  Navigator.pop(flyoutContext);
                                  _showRenameFileDialog(outerContext, file);
                                },
                              ),
                              MenuFlyoutItem(
                                leading: const Icon(Icons.delete),
                                text: const Text('Elimina'),
                                onPressed: () {
                                  Navigator.pop(flyoutContext);
                                  _showDeleteConfirmationDialog(outerContext, file);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )),
        onPressed: () {
          if (!isSelected) {
            context.read<FileSystemBloc>().add(
              OpenFile(
                fileId: file.fileId,
                projectId: projectId,
              ),
            );
          }
        },
      ),
    );
  }
}

/// Pulsante per creare un nuovo file.
class CreateFileButton extends StatelessWidget {
  final String projectId;

  const CreateFileButton({super.key, required this.projectId});

  void _showCreateFileDialog(BuildContext context, String projectId) async {
    // Mostra il dialog per definire la firma della funzione
    final functionSignature = await showCreateFunctionDialog(context);

    if (functionSignature == null) return;

    final fileName = functionSignature.name.trim().toLowerCase();
    if (fileName.isEmpty) return;

    // Valida che il nome non sia già usato
    final state = context.read<FileSystemBloc>().state;
    if (state is FileSystemLoaded) {
      final exists = state.files.any((f) => f.name.toLowerCase() == fileName);
      if (exists) {
        await AppDialogs.showInfoDialog(
          context,
          title: 'Errore',
          message: 'Esiste già un file con questo nome.',
        );
        return;
      }
    }

    // Crea la firma del flowchart
    final signature = FlowchartSignature(
      parameters: functionSignature.parameters,
      returnType: functionSignature.returnType,
    );

    context.read<FileSystemBloc>().add(CreateFile(
      projectId: projectId,
      fileName: fileName,
      signature: signature,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accentColor.withValues(alpha: 0.1),
            theme.accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        onPressed: () => _showCreateFileDialog(context, projectId),
        leading: Icon(Icons.add_circle_outline, color: theme.accentColor),
        title: Text(
          "Aggiungi Sottoprogramma",
          style: (theme.typography.body ?? const TextStyle()).copyWith(
            color: theme.accentColor.dark,
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
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _ModernMenuItem(
            iconWidget: Icon(Icons.settings_rounded,
                color: theme.typography.body?.color?.withValues(alpha: 0.7)),
            onTap: () => AppRouter.goToSettings(context),
            title: "Impostazioni",
          ),
          _ModernMenuItem(
            iconWidget: AnimatedThemeIcon(isDark: isDark),
            title: "Cambia Tema",
            onTap: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        ],
      ),
    );
  }
}

class _ModernMenuItem extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final VoidCallback onTap;

  const _ModernMenuItem(
      {required this.iconWidget, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        // Logica per determinare il colore corretto
        final Color backgroundColor;
        if (states.isEmpty) {
          // Se il bottone è a riposo, rendilo completamente trasparente
          backgroundColor = Colors.transparent;
        } else {
          // Altrimenti (hover, pressed), usa il colore del tema
          backgroundColor = ButtonThemeData.buttonColor(context, states);
        }

        return Container(
          color: backgroundColor, // Applica il colore calcolato
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(child: Text(title)),
            ],
          ),
        );
      },
    );
  }
}

/// Icona animata per il cambio tema.
class AnimatedThemeIcon extends StatelessWidget {
  final bool isDark;
  const AnimatedThemeIcon({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
        color: theme.typography.body?.color?.withValues(alpha: 0.7),
      ),
    );
  }
}

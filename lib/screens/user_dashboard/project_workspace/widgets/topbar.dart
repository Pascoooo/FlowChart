import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

class TopBar extends StatefulWidget {
  final MyProject selectedProject;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final bool isReadOnly;
  final VoidCallback? onLeave;

  const TopBar({
    super.key,
    required this.selectedProject,
    required this.onEdit,
    required this.onExport,
    this.isReadOnly = false,
    this.onLeave,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _opacityAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minBarWidth = 450.0;
        if (constraints.maxWidth < minBarWidth) {
          return const SizedBox.shrink();
        }

        return BlocBuilder<FileSystemBloc, FileSystemState>(
          builder: (context, state) {
            final Widget child;
            if (state is FileSystemLoaded) {
              child = _AdvancedTopBar(
                state: state,
                selectedProjectId: widget.selectedProject.projectId,
                selectedProjectName: widget.selectedProject.name,
                onEdit: widget.onEdit,
                onExport: widget.onExport,
                animation: _opacityAnimation,
                isReadOnly: widget.isReadOnly,
                onLeave: widget.onLeave,
              );
            } else {
              child = _SimpleTopBar(
                projectName: widget.selectedProject.name,
                onLeave: widget.onLeave,
              );
            }
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------

class _SimpleTopBar extends StatelessWidget {
  final String projectName;
  final VoidCallback? onLeave;
  const _SimpleTopBar({required this.projectName, this.onLeave});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open_rounded,
              color: theme.accentColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  projectName,
                  style: theme.typography.title
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Caricamento...',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2, activeColor: theme.accentColor),
          ),
        ],
      ),
    );
  }
}

class _AdvancedTopBar extends StatelessWidget {
  final FileSystemLoaded state;
  final String selectedProjectId;
  final String selectedProjectName;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final Animation<double> animation;
  final bool isReadOnly;
  final VoidCallback? onLeave;

  const _AdvancedTopBar({
    required this.state,
    required this.selectedProjectId,
    required this.selectedProjectName,
    required this.onEdit,
    required this.onExport,
    required this.animation,
    this.isReadOnly = false,
    this.onLeave,
  });

  Future<void> _resetFlowchart(BuildContext context) async {
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
        context,
        title: 'Conferma reset',
        message:
        'Sei sicuro di voler resettare il flowchart? Tutti i nodi tranne "Inizio" verranno eliminati.',
        confirmText: 'Resetta',
        cancelText: 'Annulla',
        isDestructive: true
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(const ResetFlowchart());
    }
  }

  Future<void> _deleteSelected(BuildContext context, String nodeId) async {
    bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Conferma eliminazione',
      message: 'Sei sicuro di voler eliminare il nodo selezionato?',
      confirmText: 'Elimina',
      cancelText: 'Annulla',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(RemoveNode(nodeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minWidthForCenterActions = 800.0;
        final bool showCenterActions =
            constraints.maxWidth >= minWidthForCenterActions;

        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: _Breadcrumb(
                            state: state,
                            selectedProjectName: selectedProjectName,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: onEdit),
                      const SizedBox(width: 8),
                      IconButton(
                          icon: const Icon(Icons.download, size: 20),
                          onPressed: onExport),
                    ],
                  ),
                ],
              ),
              if (showCenterActions && !isReadOnly)
                BlocBuilder<FlowchartBloc, FlowchartState>(
                  builder: (context, flowchartState) {
                    if (flowchartState is! FlowchartLoaded) {
                      return const SizedBox.shrink();
                    }

                    // ===== NUOVA LOGICA DI CONTROLLO =====
                    final bool hasEndNode = flowchartState.flowchart.nodes
                        .any((node) => node.kind == FlowNodeKind.end);
                    final bool isPlayEnabled =
                        state.activeFileId != null && hasEndNode;

                    // Disabilita reset se c'è solo il nodo Start
                    final nodes = flowchartState.flowchart.nodes;
                    final bool hasOnlyStartNode =
                        nodes.length == 1 && nodes.first.kind == FlowNodeKind.start;
                    final bool isResetEnabled = !hasOnlyStartNode;

                    final selectedNode = flowchartState
                        .getNodeById(flowchartState.selectedNodeId ?? '');
                    final isDeletionEnabled = selectedNode != null &&
                        selectedNode.kind != FlowNodeKind.start &&
                        flowchartState
                            .getOutgoingEdges(selectedNode.id)
                            .isEmpty;

                    return _AnimatedFlowchartActions(
                      animation: animation,
                      onReset: _resetFlowchart,
                      selectedNodeId: flowchartState.selectedNodeId,
                      isDeletionEnabled: isDeletionEnabled,
                      onDeleteSelected: _deleteSelected,
                      projectId: selectedProjectId,
                      activeFileId: state.activeFileId,
                      isPlayEnabled: isPlayEnabled,
                      isResetEnabled: isResetEnabled,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedFlowchartActions extends StatelessWidget {
  final bool isDeletionEnabled;
  final Animation<double> animation;
  final void Function(BuildContext) onReset;
  final String? selectedNodeId;
  final void Function(BuildContext, String nodeId) onDeleteSelected;
  final String projectId;
  final String? activeFileId;
  final bool isPlayEnabled;
  final bool? isResetEnabled; // aggiunto

  const _AnimatedFlowchartActions({
    required this.isDeletionEnabled,
    required this.animation,
    required this.onReset,
    this.selectedNodeId,
    required this.onDeleteSelected,
    required this.projectId,
    this.activeFileId,
    required this.isPlayEnabled,
    this.isResetEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> buttons = [];

    buttons.add(_buildAnimatedButton(
      context: context,
      tooltip: 'Elimina nodo selezionato',
      icon: Icons.delete_rounded,
      onPressed: isDeletionEnabled
          ? () => onDeleteSelected(context, selectedNodeId!)
          : null,
      interval: const Interval(0.6, 1.0),
    ));

    buttons.add(const UndoRedoControls());

    buttons.add(_buildAnimatedButton(
      context: context,
      tooltip: 'Resetta flowchart',
      icon: Icons.delete_sweep_rounded,
      onPressed: (isResetEnabled ?? true) ? () => onReset(context) : null,
      interval: const Interval(0.7, 1.0),
    ));

    buttons.add(_buildAnimatedButton(
      context: context,
      tooltip: 'Esegui Flowchart',
      icon: Icons.play_arrow_rounded,
      onPressed: isPlayEnabled
          ? () {
              context.read<FileSystemBloc>().add(ExecuteActiveFile(
                    projectId: projectId,
                    fileId: activeFileId!,
                  ));
            }
          : null,
      interval: const Interval(0.8, 1.0),
    ));

    // Nuovo pulsante Debug
    buttons.add(_buildAnimatedButton(
      context: context,
      tooltip: 'Debug Flowchart',
      icon: Icons.bug_report,
      onPressed: () {
        context.read<FlowchartBloc>().add(const DebugFlowchart());
      },
      interval: const Interval(0.9, 1.0),
    ));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(buttons.length, (index) {
        return Padding(
          padding: EdgeInsets.only(left: index > 0 ? 8.0 : 0.0),
          child: buttons[index],
        );
      }),
    );
  }

  Widget _buildAnimatedButton({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    required Interval interval,
  }) {
    final tween = Tween<double>(begin: 0.0, end: 1.0);
    final curvedAnimation = CurvedAnimation(parent: animation, curve: interval);

    return FadeTransition(
      opacity: tween.animate(curvedAnimation),
      child: ScaleTransition(
        scale: tween.animate(curvedAnimation),
        child: Tooltip(
          message: tooltip,
          child: AnimatedOpacity(
            opacity: onPressed == null ? 0.4 : 1.0, // stesso effetto di Undo/Redo
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              style: ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
              icon: Icon(icon, size: 20),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  final FileSystemLoaded state;
  final String selectedProjectName;

  const _Breadcrumb({required this.state, required this.selectedProjectName});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    String currentFileName = "";

    if (state.files.isNotEmpty) {
      final matchingFile = state.files.firstWhere(
              (file) => file.fileId == state.activeFileId,
          orElse: () => MyFile.empty);
      currentFileName = matchingFile.name;
    }

    final textStyle = theme.typography.caption;
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right,
        size: 20,
        color: theme.typography.body?.color?.withValues(alpha: 0.4),
      ),
    );

    return Row(
      children: [
        Icon(FontAwesomeIcons.file,
            size: 16, color: theme.accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            selectedProjectName,
            style: textStyle?.copyWith(
                color: theme.accentColor, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        separator,
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accentColor.lighter.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              currentFileName,
              style: textStyle?.copyWith(
                  color: theme.accentColor.lighter,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class UndoRedoControls extends StatelessWidget {
  const UndoRedoControls({super.key});

  @override
  Widget build(BuildContext context) {
    final canUndo = context.select((FlowchartBloc bloc) => bloc.canUndo);
    final canRedo = context.select((FlowchartBloc bloc) => bloc.canRedo);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UndoRedoButton(
          icon: Icons.undo_rounded,
          tooltip: 'Annulla',
          enabled: canUndo,
          onPressed:
          canUndo ? () => context.read<FlowchartBloc>().add(const Undo()) : null,
        ),
        const SizedBox(width: 4),
        _UndoRedoButton(
          icon: Icons.redo_rounded,
          tooltip: 'Ripeti',
          enabled: canRedo,
          onPressed:
          canRedo ? () => context.read<FlowchartBloc>().add(const Redo()) : null,
        ),
      ],
    );
  }
}

class _UndoRedoButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onPressed;

  const _UndoRedoButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          style: const ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          ),
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

import 'package:file_repository/file_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/banner_service.dart';

class TopBar extends StatefulWidget {
  final MyProject selectedProject;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final bool isReadOnly; // nuovo flag
  final VoidCallback? onLeave; // callback uscita

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
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open_rounded,
              color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  projectName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Caricamento...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _AdvancedTopBar extends StatelessWidget {
  final FileSystemLoaded state;
  final String selectedProjectName;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final Animation<double> animation;
  final bool isReadOnly; // <-- già dichiarato sopra ma ora lo manteniamo
  final VoidCallback? onLeave;

  const _AdvancedTopBar({
    required this.state,
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
    );
    if (confirmed == true && context.mounted) {
      context.read<FlowchartBloc>().add(RemoveNode(nodeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minWidthForCenterActions = 750.0;
        final bool showCenterActions =
            constraints.maxWidth >= minWidthForCenterActions;

        return Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.1),
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
                  // BLOCCO SINISTRA: back + breadcrumb
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

                    final selectedNode = flowchartState.getNodeById(flowchartState.selectedNodeId ?? '');
                    final isDeletionEnabled = selectedNode != null &&
                        selectedNode.kind != FlowNodeKind.start &&
                        flowchartState.getOutgoingEdges(selectedNode.id).isEmpty;

                    return _AnimatedFlowchartActions(
                      animation: animation,
                      onReset: _resetFlowchart,
                      selectedNodeId: flowchartState.selectedNodeId,
                      isDeletionEnabled: isDeletionEnabled,
                      onDeleteSelected: _deleteSelected,
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

  const _AnimatedFlowchartActions({
    required this.isDeletionEnabled,
    required this.animation,
    required this.onReset,
    this.selectedNodeId,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      _buildAnimatedButton(
        context: context,
        tooltip: 'Elimina nodo selezionato',
        icon: Icons.delete_rounded,
        onPressed: isDeletionEnabled
            ? () => onDeleteSelected(context, selectedNodeId!)
            : null,
        interval: const Interval(0.6, 1.0),
      ),
      const UndoRedoControls(),
      _buildAnimatedButton(
        context: context,
        tooltip: 'Resetta flowchart',
        icon: Icons.delete_sweep_rounded,
        onPressed: () => onReset(context),
        interval: const Interval(0.7, 1.0),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(buttons.length, (index) {
        if (index == 0) return buttons[index];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [const SizedBox(width: 8), buttons[index]],
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
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
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
    final theme = Theme.of(context);
    String currentFileName = "";

    if (state.files.isNotEmpty) {
      final matchingFile = state.files.firstWhere(
              (file) => file.fileId == state.activeFileId,
          orElse: () => MyFile.empty);
      currentFileName = matchingFile.name;
    }

    final textStyle =
    theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
    final separator = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
      ),
    );

    return Row(
      children: [
        Icon(Icons.auto_awesome,
            size: 16, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            selectedProjectName,
            style: textStyle?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        separator,
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              currentFileName,
              style: textStyle?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600),
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
    // Ora usiamo context.select per rebuildare solo questo widget
    // quando canUndo o canRedo cambiano. È più efficiente.
    final canUndo = context.select((FlowchartBloc bloc) => bloc.canUndo);
    final canRedo = context.select((FlowchartBloc bloc) => bloc.canRedo);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UndoRedoButton(
          icon: Icons.undo_rounded,
          tooltip: 'Annulla',
          enabled: canUndo,
          onPressed: canUndo ? () => context.read<FlowchartBloc>().add(const Undo()) : null,
        ),
        const SizedBox(width: 4),
        _UndoRedoButton(
          icon: Icons.redo_rounded,
          tooltip: 'Ripeti',
          enabled: canRedo,
          onPressed: canRedo ? () => context.read<FlowchartBloc>().add(const Redo()) : null,
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
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: IconButton(
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          color: enabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }
}

class KeyboardShortcuts extends StatelessWidget {
  final Widget child;

  const KeyboardShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
        const UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY):
        const RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyZ): const RedoIntent(),
      },
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (UndoIntent intent) {
              final bloc = context.read<FlowchartBloc>();
              if (bloc.canUndo) {
                bloc.add(const Undo());
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (RedoIntent intent) {
              final bloc = context.read<FlowchartBloc>();
              if (bloc.canRedo) {
                bloc.add(const Redo());
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}
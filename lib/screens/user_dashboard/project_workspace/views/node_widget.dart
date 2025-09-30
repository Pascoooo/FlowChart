import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:file_repository/file_repository.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'painters.dart';

enum HandleDirection { top, right, bottom, left }

class NodeWidget extends StatefulWidget {
  final FlowNode node;
  final BoxConstraints canvasConstraints;
  final bool isSelected;
  final bool isReadOnly;
  final bool allowDragInReadOnly; // nuovo

  const NodeWidget({
    super.key,
    required this.node,
    required this.canvasConstraints,
    required this.isSelected,
    this.isReadOnly = false,
    this.allowDragInReadOnly = false,
  });

  @override
  State<NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<NodeWidget> {
  late Offset _dragPosition;
  bool _isDragging = false;

  static const double handleSize = 24.0;
  static const double gap = 8.0;
  static const double handleAreaPadding = handleSize + gap + 24.0;
  static const double topPaddingForButton = 42.0;

  @override
  void initState() {
    super.initState();
    _dragPosition = Offset(widget.node.x, widget.node.y);
  }

  @override
  void didUpdateWidget(covariant NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        (oldWidget.node.x != widget.node.x ||
            oldWidget.node.y != widget.node.y)) {
      _dragPosition = Offset(widget.node.x, widget.node.y);
    }
  }

  double _clampX(double x) => x.clamp(10.0, widget.canvasConstraints.maxWidth - widget.node.width - 10.0);
  double _clampY(double y) => y.clamp(10.0, widget.canvasConstraints.maxHeight - widget.node.height - 10.0);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _dragPosition.dx - handleAreaPadding,
      top: _dragPosition.dy - topPaddingForButton - handleAreaPadding,
      width: widget.node.width + 2 * handleAreaPadding,
      height: widget.node.height + topPaddingForButton + 2 * handleAreaPadding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: handleAreaPadding,
            top: handleAreaPadding,
            width: widget.node.width,
            height: widget.node.height + topPaddingForButton,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Mostra l'eye button solo quando il nodo è selezionato.
                if (widget.isSelected)
                  Positioned(
                    top: 0,
                    child: _EyeButton(
                      onTap: () => AppDialogs.showNodeDetailsDialog(
                        context: context,
                        node: widget.node,
                      ),
                    ),
                  ),
                Positioned(
                  top: topPaddingForButton,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Il tap seleziona sempre il nodo (anche in sola lettura). Il dialog si apre dall'eye button.
                    onTap: () {
                      if (!widget.isSelected) {
                        context.read<FlowchartBloc>().add(SelectNode(widget.node.id));
                      }
                    },
                    onPanStart: (!widget.isReadOnly || widget.allowDragInReadOnly) && widget.isSelected
                        ? (_) => setState(() => _isDragging = true)
                        : null,
                    onPanUpdate: (!widget.isReadOnly || widget.allowDragInReadOnly) && widget.isSelected
                        ? (details) {
                            setState(() {
                              _dragPosition = Offset(
                                _clampX(_dragPosition.dx + details.delta.dx),
                                _clampY(_dragPosition.dy + details.delta.dy),
                              );
                            });
                          }
                        : null,
                    onPanEnd: (!widget.isReadOnly || widget.allowDragInReadOnly) && widget.isSelected
                        ? (_) {
                            setState(() => _isDragging = false);
                            context.read<FlowchartBloc>().add(UpdateNodePosition(
                                  nodeId: widget.node.id,
                                  newX: _dragPosition.dx,
                                  newY: _dragPosition.dy,
                                  oldX: widget.node.x,
                                  oldY: widget.node.y,
                                ));
                          }
                        : null,
                    child: MouseRegion(
                      cursor: (!widget.isReadOnly || widget.allowDragInReadOnly)
                          ? (widget.isSelected ? SystemMouseCursors.move : SystemMouseCursors.click)
                          : (widget.isSelected ? SystemMouseCursors.basic : SystemMouseCursors.click),
                      child: NodeRenderer(
                        node: widget.node,
                        isSelected: widget.isSelected,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._getAvailableHandles(context)
              .map((dir) => _buildCreationHandle(context, dir)),
        ],
      ),
    );
  }

  Widget _buildCreationHandle(BuildContext context, HandleDirection direction) {
    final handleCenter = _getHandleCenter(direction);
    final handleTopLeft = Offset(
      handleAreaPadding + handleCenter.dx - (handleSize / 2),
      handleAreaPadding + topPaddingForButton + handleCenter.dy - (handleSize / 2),
    );

    return Positioned(
      left: handleTopLeft.dx,
      top: handleTopLeft.dy,
      child: _CreationHandleButton(
        canvasConstraints: widget.canvasConstraints,
        onNodeCreate: (kind) => _createNode(context, kind, _resolvePort(direction)),
        absolutePosition: Offset(
            _dragPosition.dx - handleAreaPadding + handleTopLeft.dx,
            _dragPosition.dy - topPaddingForButton - handleAreaPadding + handleTopLeft.dy),
      ),
    );
  }

  Offset _getHandleCenter(HandleDirection direction) {
    const double bottomGap = 20.0;
    switch (direction) {
      case HandleDirection.bottom: return Offset(widget.node.width / 2, widget.node.height + bottomGap);
      case HandleDirection.top: return Offset(widget.node.width / 2, -gap);
      case HandleDirection.left: return Offset(-gap, widget.node.height / 2);
      case HandleDirection.right: return Offset(widget.node.width + gap, widget.node.height / 2);
    }
  }

  List<HandleDirection> _getAvailableHandles(BuildContext context) {
    if (widget.isReadOnly || !widget.isSelected) return [];
    // in sola lettura, anche con drag abilitato, gli handle restano disabilitati

    final state = context.read<FlowchartBloc>().state;
    if (state is! FlowchartLoaded) return [];

    switch (widget.node.kind) {
      case FlowNodeKind.decision:
        final outgoingEdges = state.getOutgoingEdges(widget.node.id);
        final hasFalseBranch = outgoingEdges.any((e) => e.port == 'false');
        final hasTrueBranch = outgoingEdges.any((e) => e.port == 'true');
        final handles = <HandleDirection>[];
        if (!hasFalseBranch) handles.add(HandleDirection.left);
        if (!hasTrueBranch) handles.add(HandleDirection.right);
        return handles;
      case FlowNodeKind.end:
        return [];
      default:
        return state.canAddOutgoingConnection(widget.node.id)
            ? [HandleDirection.bottom]
            : [];
    }
  }

  void _createNode(BuildContext context, FlowNodeKind kind, String? fromPort) async {
    try {
      final bloc = context.read<FlowchartBloc>();
      final flowState = bloc.state;

      if (kind == FlowNodeKind.end && flowState is FlowchartLoaded) {
        final hasEndNode = flowState.flowchart.nodes.any((n) => n.kind == FlowNodeKind.end);
        if (hasEndNode) {
          final bool? confirmed = await AppDialogs.showConfirmationDialog(
            context,
            title: 'Collega al nodo "Fine"',
            message: 'Esiste già un nodo di fine nel flowchart. Vuoi collegare questo nodo al "Fine" esistente?',
            confirmText: 'Collega',
            cancelText: 'Annulla',

          );
          if (confirmed == true && mounted) {
            bloc.add(LinkToExistingEnd(fromNodeId: widget.node.id, fromPort: fromPort));
          }
          return;
        }
      }

      List<MyFile>? filesForProcess;
      List<VariableDeclaration>? variablesForDialog;
      if (kind == FlowNodeKind.process) {
        final fsState = context.read<FileSystemBloc>().state;
        if (fsState is FileSystemLoaded) {
          filesForProcess = fsState.files.where((f) => f.fileId != fsState.activeFileId).toList();
        }
      }
      if (kind == FlowNodeKind.input || kind == FlowNodeKind.decision || kind == FlowNodeKind.output) {
        if (flowState is FlowchartLoaded) {
          variablesForDialog = flowState.flowchart.variables;
        }
      }



      final Map<String, dynamic>? nodeData = await AppDialogs.showNodeCreationDialog(
        context: context,
        kind: kind,
        files: filesForProcess,
        variables: variablesForDialog,
      );

      if (nodeData != null) {
        bloc.add(AddNode(
          kind: kind,
          fromNodeId: widget.node.id,
          fromPort: fromPort,
          canvasConstraints: widget.canvasConstraints,
          initialData: nodeData,
        ));
      }
    } catch (_) {}
  }

  String? _resolvePort(HandleDirection direction) {
    if (widget.node.kind == FlowNodeKind.decision) {
      switch (direction) {
        case HandleDirection.left: return 'false';
        case HandleDirection.right: return 'true';
        default: return null;
      }
    }
    return null;
  }
}

class _EyeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EyeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Button(
      onPressed: onTap,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        backgroundColor: WidgetStatePropertyAll(theme.cardColor.withValues(alpha: 0.95)),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Center(
          child: Icon(FluentIcons.view, size: 18, color: theme.typography.body?.color),
        ),
      ),
    );
  }
}

class NodeRenderer extends StatelessWidget {
  final FlowNode node;
  final bool isSelected;
  const NodeRenderer({super.key, required this.node, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      color: Colors.black,
    );
    final borderColor = isSelected ? theme.accentColor : Colors.blue;
    final borderWidth = isSelected ? 2.5 : 1.5;
    const fillColor = Colors.white;

    Widget nodeContent;
    switch (node.kind) {
      case FlowNodeKind.decision:
        nodeContent = CustomPaint(
          painter: DiamondPainter(color: fillColor, borderColor: borderColor, strokeWidth: borderWidth),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(node.text, textAlign: TextAlign.center, style: textStyle),
              ),
            ),
          ),
        );
        break;
      case FlowNodeKind.input:
      case FlowNodeKind.output:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(fillColor: fillColor, borderColor: borderColor, strokeWidth: borderWidth, reversed: node.kind == FlowNodeKind.output),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        );
        break;
      default:
        nodeContent = Container(
          width: node.width,
          height: node.height,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular((node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end) ? 999 : 8),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [if (isSelected) BoxShadow(color: theme.accentColor.withValues(alpha: 0.25), blurRadius: 8)],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                node.text,
                textAlign: TextAlign.center,
                style: textStyle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
        break;
    }
    return nodeContent;
  }
}
class _CreationHandleButton extends StatefulWidget {
  final BoxConstraints canvasConstraints;
  final Function(FlowNodeKind) onNodeCreate;
  final Offset absolutePosition;

  const _CreationHandleButton({
    required this.canvasConstraints,
    required this.onNodeCreate,
    required this.absolutePosition,
  });

  @override
  State<_CreationHandleButton> createState() => _CreationHandleButtonState();
}

class _CreationHandleButtonState extends State<_CreationHandleButton> {
  final FlyoutController _flyoutController = FlyoutController();
  static const double handleSize = 24.0;

  @override
  void initState() {
    super.initState();
    _flyoutController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bool isOpen = _flyoutController.isOpen;

    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        onTap: () {
          if (isOpen) {
            _flyoutController.close();
          } else {
            const double estimatedMenuHeight = 230.0;
            final double spaceBelow =
                widget.canvasConstraints.maxHeight - (widget.absolutePosition.dy + handleSize);

            final placement = spaceBelow >= estimatedMenuHeight
                ? FlyoutPlacementMode.bottomCenter
                : FlyoutPlacementMode.topCenter;

            _flyoutController.showFlyout(
              placementMode: placement,
              builder: (flyoutContext) {
                return MenuFlyout(
                  items: _buildMenuFlyoutItems(flyoutContext),
                );
              },
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // --- STILE UGUALE A _EyeButton ---
            color: theme.cardColor.withValues(alpha: 0.95),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(
                FontAwesomeIcons.plus,
                size: 20,
                color: theme.typography.body?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<MenuFlyoutItemBase> _buildMenuFlyoutItems(BuildContext flyoutContext) {
    MenuFlyoutItem buildItem(String label, IconData icon, FlowNodeKind kind) {
      final theme = FluentTheme.of(context);
      return MenuFlyoutItem(
        onPressed: () {
          Navigator.pop(flyoutContext);
          widget.onNodeCreate(kind);
        },
        text: Text(label, style: TextStyle(fontSize: 13, color: theme.typography.body?.color)),
        leading: Icon(icon, size: 16, color: theme.typography.body?.color?.withValues(alpha: 0.8)),
      );
    }
    return [
      buildItem('Input', FontAwesomeIcons.download, FlowNodeKind.input),
      buildItem('Output', FontAwesomeIcons.upload, FlowNodeKind.output),
      buildItem('Processo', FontAwesomeIcons.gear, FlowNodeKind.process),
      buildItem('Condizione', FontAwesomeIcons.codeBranch, FlowNodeKind.decision),
      const MenuFlyoutSeparator(),
      buildItem('Fine', FontAwesomeIcons.flagCheckered, FlowNodeKind.end),
    ];
  }
}
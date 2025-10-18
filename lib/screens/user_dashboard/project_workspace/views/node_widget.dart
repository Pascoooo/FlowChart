import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/debug_bloc/debug_bloc_exports.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'painters.dart';
import 'node_creation_service.dart';

enum HandleDirection { top, right, bottom, left }

class NodeWidget extends StatefulWidget {
  final FlowNode node;
  final BoxConstraints canvasConstraints;
  final bool isSelected;
  final bool isReadOnly;
  final bool allowDragInReadOnly;

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

  double _clampX(double x) => x.clamp(
      10.0, widget.canvasConstraints.maxWidth - widget.node.width - 10.0);
  double _clampY(double y) => y.clamp(
      10.0, widget.canvasConstraints.maxHeight - widget.node.height - 10.0);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is! FlowchartLoaded) {
          return const SizedBox.shrink();
        }

        // ✅ NUOVO: Verifica se siamo in debug mode
        final debugState = context.watch<DebugBloc>().state;
        final isInDebugMode = debugState is DebugInProgress || debugState is DebugAwaitingInput;

        final bool isConnectorMode = state.isConnectorModeActive;
        final bool isThisNodeTheSource =
            state.connectorSourceNodeId == widget.node.id;

        // ⚠️ NUOVO: Verifica se siamo in modalità selezione corpo do-while o reset parziale
        final connectorPurpose = state.connectorPurpose;
        final sourceNode = state.connectorSourceNodeId != null
            ? state.getNodeById(state.connectorSourceNodeId!)
            : null;
        final isDoWhileBodySelection = connectorPurpose == ConnectorPurpose.doWhileBody; // solo dal purpose
        final isResetSelection = connectorPurpose == ConnectorPurpose.resetFromNode;

        // Calcola l'insieme di nodi validi per do-while: devono essere PRIMA del do-while
        final allowedAncestors = isDoWhileBodySelection && sourceNode != null
            ? state.nodesThatCanReach(sourceNode.id)
            : const <String>{};

        // Nodo Start non selezionabile come inizio corpo o reset
        final isStartNode = widget.node.kind == FlowNodeKind.start;
        // REQUISITO: Anche il FunctionHeader non è selezionabile per il reset
        final isHeaderNode = widget.node.kind == FlowNodeKind.functionHeader;
        // 🔒 Nodo Fine: non selezionabile in connector mode come target e non deve avviare connector
        final isEndNode = widget.node.kind == FlowNodeKind.end;

        // Valida il target in base alla modalità
        final bool isThisNodeAValidTarget = isDoWhileBodySelection
            ? (!isThisNodeTheSource && !isStartNode && allowedAncestors.contains(widget.node.id))
            : (isResetSelection
                ? (!isStartNode && !isHeaderNode)
                : (state.isLeafNode(widget.node.id) && !isThisNodeTheSource && !isEndNode));

        final bool isThisNodeSelectedForConnector =
            state.selectedConnectorNodeIds.contains(widget.node.id);

        final bool isDimmed =
            isConnectorMode && !isThisNodeAValidTarget && !isThisNodeTheSource;

        void handleTap() {
          // ✅ FIXED: Disabilita completamente i click in debug mode
          if (isInDebugMode) {
            return; // Ignora i click quando siamo in debug mode
          }

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      // 🆕 In modalità selezione corpo do-while: cliccando su un altro do-while si cambia la sorgente
          if (isConnectorMode && isDoWhileBodySelection) {
            if (widget.node.kind == FlowNodeKind.doWhileLoop) {
              context.read<FlowchartBloc>().add(StartDoWhileBodySelection(widget.node.id));
              return;
            }
          }

          if (isConnectorMode) {
            if (isThisNodeAValidTarget) {
              // 🆕 Se stiamo scegliendo l'inizio del corpo di un do-while, conferma subito la scelta
              if (isDoWhileBodySelection && sourceNode != null) {
                context.read<FlowchartBloc>().add(SelectDoWhileBodyStart(
                  doWhileNodeId: sourceNode.id,
                  bodyStartNodeId: widget.node.id,
                ));
              } else {
                context
                    .read<FlowchartBloc>()
                    .add(ToggleConnectorNodeSelection(widget.node.id));
              }
            }
          } else {
            if (!widget.isSelected) {
              context.read<FlowchartBloc>().add(SelectNode(widget.node.id));
            }
          }
        }

        return Positioned(
          left: _dragPosition.dx - handleAreaPadding,
          top: _dragPosition.dy - topPaddingForButton - handleAreaPadding,
          width: widget.node.width + 2 * handleAreaPadding,
          height:
              widget.node.height + topPaddingForButton + 2 * handleAreaPadding,
          child: Opacity(
            opacity: isDimmed ? 0.4 : 1.0,
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
                      // Pulsante dettagli nodo (occhio) - mostrato solo se selezionato, non in modalità connettore E NON in debug mode
                      if (widget.isSelected && !isConnectorMode && !isInDebugMode)
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
                          onTap: handleTap,
                          onPanStart: (!widget.isReadOnly ||
                                      widget.allowDragInReadOnly) &&
                                  widget.isSelected &&
                                  !isConnectorMode &&
                                  !isInDebugMode
                              ? (_) => setState(() => _isDragging = true)
                              : null,
                          onPanUpdate: (!widget.isReadOnly ||
                                      widget.allowDragInReadOnly) &&
                                  widget.isSelected &&
                                  !isConnectorMode &&
                                  !isInDebugMode
                              ? (details) {
                                  setState(() {
                                    _dragPosition = Offset(
                                      _clampX(
                                          _dragPosition.dx + details.delta.dx),
                                      _clampY(
                                          _dragPosition.dy + details.delta.dy),
                                    );
                                  });
                                }
                              : null,
                          onPanEnd: (!widget.isReadOnly ||
                                      widget.allowDragInReadOnly) &&
                                  widget.isSelected &&
                                  !isConnectorMode &&
                                  !isInDebugMode
                              ? (_) {
                                  setState(() => _isDragging = false);
                                  context
                                      .read<FlowchartBloc>()
                                      .add(UpdateNodePosition(
                                        nodeId: widget.node.id,
                                        newX: _dragPosition.dx,
                                        newY: _dragPosition.dy,
                                        oldX: widget.node.x,
                                        oldY: widget.node.y,
                                      ));
                                }
                              : null,
                          child: MouseRegion(
                            cursor: isConnectorMode
                                ? (isThisNodeAValidTarget
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic)
                                : (isInDebugMode
                                    ? SystemMouseCursors.basic
                                    : ((!widget.isReadOnly ||
                                            widget.allowDragInReadOnly)
                                        ? (widget.isSelected
                                            ? SystemMouseCursors.move
                                            : SystemMouseCursors.click)
                                        : (widget.isSelected
                                            ? SystemMouseCursors.basic
                                            : SystemMouseCursors.click))),
                            child: NodeRenderer(
                              node: widget.node,
                              isSelected: widget.isSelected,
                              isConnectorSelected:
                                  isThisNodeSelectedForConnector,
                            ),
                          ),
                        ),
                      ),

                      // 🆕 Badge di selezione (spunta) visibile SOLO in modalità speciale (connector/reset/do-while)
                      if (isConnectorMode && (isThisNodeSelectedForConnector || isThisNodeTheSource))
                        Positioned(
                          top: topPaddingForButton - 12,
                          right: -8,
                          child: _SelectionBadge(isSource: isConnectorMode && isThisNodeTheSource),
                        ),
                    ],
                  ),
                ),
                if (!isConnectorMode && !isInDebugMode)
                  ..._getAvailableHandles(context)
                      .map((dir) => _buildCreationHandle(context, dir)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreationHandle(BuildContext context, HandleDirection direction) {
    final handleCenter = _getHandleCenter(direction);
    final handleTopLeft = Offset(
      handleAreaPadding + handleCenter.dx - (handleSize / 2),
      handleAreaPadding +
          topPaddingForButton +
          handleCenter.dy -
          (handleSize / 2),
    );

    return Positioned(
      left: handleTopLeft.dx,
      top: handleTopLeft.dy,
      child: _CreationHandleButton(
        sourceNodeId: widget.node.id,
        canvasConstraints: widget.canvasConstraints,
        onNodeCreate: (kind) =>
            _createNode(context, kind, _resolvePort(direction)),
        absolutePosition: Offset(
            _dragPosition.dx - handleAreaPadding + handleTopLeft.dx,
            _dragPosition.dy -
                topPaddingForButton -
                handleAreaPadding +
                handleTopLeft.dy),
      ),
    );
  }

  Offset _getHandleCenter(HandleDirection direction) {
    const double bottomGap = 20.0;
    switch (direction) {
      case HandleDirection.bottom:
        return Offset(widget.node.width / 2, widget.node.height + bottomGap);
      case HandleDirection.top:
        return Offset(widget.node.width / 2, -gap);
      case HandleDirection.left:
        return Offset(-gap, widget.node.height / 2);
      case HandleDirection.right:
        return Offset(widget.node.width + gap, widget.node.height / 2);
    }
  }

  List<HandleDirection> _getAvailableHandles(BuildContext context) {
    if (widget.isReadOnly || !widget.isSelected) return [];

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
      case FlowNodeKind.whileLoop:
        // While: true va in BASSO (corpo del ciclo), false va a DESTRA (uscita)
        final outgoingEdges = state.getOutgoingEdges(widget.node.id);
        final hasFalseBranch = outgoingEdges.any((e) => e.port == 'false');
        final hasTrueBranch = outgoingEdges.any((e) => e.port == 'true');
        final handles = <HandleDirection>[];
        if (!hasFalseBranch) handles.add(HandleDirection.right); // False esce a destra
        if (!hasTrueBranch) handles.add(HandleDirection.bottom); // True va in basso (corpo ciclo)
        return handles;
      case FlowNodeKind.doWhileLoop:
        // Do-While: SOLO uscita a DESTRA (false)
        // Il corpo viene collegato tramite dialog di selezione dopo la creazione
        final outgoingEdges = state.getOutgoingEdges(widget.node.id);
        final hasFalseBranch = outgoingEdges.any((e) => e.port == 'false');
        final handles = <HandleDirection>[];
        if (!hasFalseBranch) handles.add(HandleDirection.right); // Solo false esce a destra
        // NON mostrare mai handle per 'true' (corpo): si seleziona tramite dialog
        return handles;
      case FlowNodeKind.end:
      case FlowNodeKind.returnNode: // REQUISITO: Anche il ReturnNode è terminale
        return [];
      default:
        return state.canAddOutgoingConnection(widget.node.id)
            ? [HandleDirection.bottom]
            : [];
    }
  }

  void _createNode(
      BuildContext context, FlowNodeKind kind, String? fromPort) async {
    if (!mounted) return;
    final bloc = context.read<FlowchartBloc>();

    try {
      NodeCreationService.createNode(
        context: context,
        kind: kind,
        sourceNodeId: widget.node.id,
        fromPort: fromPort,
        canvasConstraints: widget.canvasConstraints,
      ).then((nodeData) {
        if (nodeData != null && mounted) {
          bloc.add(AddNode(
            kind: kind,
            fromNodeId: widget.node.id,
            fromPort: fromPort,
            canvasConstraints: widget.canvasConstraints,
            initialData: nodeData,
          ));
        }
      });
    } catch (e) {
      debugPrint("Errore durante la creazione del nodo: $e");
    }
  }

  String? _resolvePort(HandleDirection direction) {
    if (widget.node.kind == FlowNodeKind.decision) {
      return direction == HandleDirection.left ? 'false' : 'true';
    }
    if (widget.node.kind == FlowNodeKind.whileLoop) {
      // Per il while: bottom = true (corpo), right = false (uscita)
      return direction == HandleDirection.bottom ? 'true' : 'false';
    }
    if (widget.node.kind == FlowNodeKind.doWhileLoop) {
      // Per il do-while: bottom = true (inizio corpo), right = false (uscita)
      return direction == HandleDirection.bottom ? 'true' : 'false';
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
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        shape: WidgetStateProperty.all(const CircleBorder()),
        backgroundColor:
            WidgetStateProperty.all(theme.cardColor.withValues(alpha: 0.95)),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
          ],
        ),
        child: Center(
          child: Icon(FluentIcons.view,
              size: 18, color: theme.typography.body?.color),
        ),
      ),
    );
  }
}

class NodeRenderer extends StatelessWidget {
  final FlowNode node;
  final bool isSelected;
  final bool isConnectorSelected;

  const NodeRenderer(
      {super.key,
      required this.node,
      required this.isSelected,
      this.isConnectorSelected = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    // Testo da mostrare: per FunctionHeader usa la firma generata
    final String displayText =
        (node is FunctionHeaderNode) ? (node as FunctionHeaderNode).signatureText : node.text;
    // Grassetto solo per selezione normale
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      color: Colors.black,
    );

    // 🆕 Mantieni sempre il bordo visibile; niente trasparenza in connector mode
    final borderColor = isSelected ? theme.accentColor : Colors.blue;
    final borderWidth = isSelected ? 2.5 : 1.5;
    const fillColor = Colors.white;

    Widget nodeContent;
    switch (node.kind) {
      case FlowNodeKind.decision:
        nodeContent = CustomPaint(
          painter: DiamondPainter(
            color: fillColor,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ),
          ),
        );
        break;

      case FlowNodeKind.whileLoop:
      case FlowNodeKind.doWhileLoop:
        // Rombo con colore diverso per distinguerli dalla Decision
        final loopBorderColor = isSelected ? theme.accentColor : Colors.green;

        nodeContent = CustomPaint(
          painter: DiamondPainter(
            color: fillColor,
            borderColor: loopBorderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ),
          ),
        );
        break;

      case FlowNodeKind.input:
      case FlowNodeKind.output:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(
            fillColor: fillColor,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: node.kind == FlowNodeKind.output,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
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
            borderRadius: BorderRadius.circular(
              (node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end)
                  ? 999
                  : 8,
            ),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: theme.accentColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                displayText,
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          (node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end)
              ? 999
              : 10,
        ),
        boxShadow: const [],
      ),
      child: nodeContent,
    );
  }
}

class _CreationHandleButton extends StatefulWidget {
  final String sourceNodeId;
  final BoxConstraints canvasConstraints;
  final Function(FlowNodeKind) onNodeCreate;
  final Offset absolutePosition;

  const _CreationHandleButton({
    required this.sourceNodeId,
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
            const double estimatedMenuHeight = 260.0;
            final double spaceBelow = widget.canvasConstraints.maxHeight -
                (widget.absolutePosition.dy + handleSize);
            final placement = spaceBelow >= estimatedMenuHeight
                ? FlyoutPlacementMode.bottomCenter
                : FlyoutPlacementMode.topCenter;

            _flyoutController.showFlyout(
              placementMode: placement,
              builder: (flyoutContext) {
                return MenuFlyout(items: _buildMenuFlyoutItems(flyoutContext));
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
            color: theme.cardColor.withValues(alpha: 0.95),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(FontAwesomeIcons.plus,
                  size: 16,
                  color: theme.typography.body?.color?.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
    );
  }

  List<MenuFlyoutItemBase> _buildMenuFlyoutItems(BuildContext flyoutContext) {
    final bloc = context.read<FlowchartBloc>();
    final state = bloc.state;

    bool isSourceNodeLeaf = false;
    bool hasOtherLeafNodes = false;
    bool isInsideLoop = false;
    String? loopNodeId;
    final bool isFunctionFlowchart =
        state is FlowchartLoaded ? state.flowchart.isFunction : false;

    // 🆕 Valuta candidati reali per do-while: presenza di almeno un blocco oltre a Start
    bool hasEligibleDoWhileCandidates = false;

    // 🆕 Valuta se il flowchart contiene solo il nodo Inizio
    bool onlyStart = false;
    if (state is FlowchartLoaded) {
      final nodes = state.flowchart.nodes;
      onlyStart = nodes.length == 1 && nodes.first.kind == FlowNodeKind.start;

      // Mostra il do-while se c'è almeno un blocco oltre a Start
      hasEligibleDoWhileCandidates = !onlyStart;
    }

    if (state is FlowchartLoaded) {
      isSourceNodeLeaf = state.isLeafNode(widget.sourceNodeId);
      loopNodeId = state.getParentLoopNodeId(widget.sourceNodeId);
      isInsideLoop = loopNodeId != null;
      if (isSourceNodeLeaf) {
        // Considera solo nodi foglia VALIDi come altri candidati: non End e con capacità di uscita
        hasOtherLeafNodes = state.flowchart.nodes.any(
          (node) =>
              state.isLeafNode(node.id) &&
              node.id != widget.sourceNodeId &&
              node.kind != FlowNodeKind.end &&
              state.canAddOutgoingConnection(node.id),
        );
      }
    }

    MenuFlyoutItem _item(String label, IconData icon, VoidCallback onPressed) => MenuFlyoutItem(
          onPressed: () {
            Navigator.pop(flyoutContext);
            onPressed();
          },
          text: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: FluentTheme.of(context).typography.body?.color,
            ),
          ),
          leading: Icon(
            icon,
            size: 16,
            color: FluentTheme.of(context).typography.body?.color?.withValues(alpha: 0.8),
          ),
        );

    final items = <MenuFlyoutItemBase>[];

    items.addAll([
      _item('Input', FontAwesomeIcons.download,
          () => widget.onNodeCreate(FlowNodeKind.input)),
      _item('Assegnazione', FontAwesomeIcons.calculator,
          () => widget.onNodeCreate(FlowNodeKind.assignment)),
      _item('Output', FontAwesomeIcons.upload,
          () => widget.onNodeCreate(FlowNodeKind.output)),
      _item('Condizione', FontAwesomeIcons.codeBranch,
          () => widget.onNodeCreate(FlowNodeKind.decision)),
      _item('Sottoprogramma', FontAwesomeIcons.gears,
          () => widget.onNodeCreate(FlowNodeKind.process)),
      if (isFunctionFlowchart)
        _item('Return', FontAwesomeIcons.reply,
            () => widget.onNodeCreate(FlowNodeKind.returnNode)),
      const MenuFlyoutSeparator(),
    ]);

    if (!isInsideLoop) {
      items.addAll([
        _item('Ciclo Pre-Condizionale', FontAwesomeIcons.arrowsRotate,
            () => widget.onNodeCreate(FlowNodeKind.whileLoop)),
        // Mostra Post-Condizionale appena c'è almeno un blocco oltre a Start
        if (hasEligibleDoWhileCandidates)
          _item('Ciclo Post-Condizionale', FontAwesomeIcons.repeat,
              () => widget.onNodeCreate(FlowNodeKind.doWhileLoop)),
        const MenuFlyoutSeparator(),
      ]);
    }

    if (isInsideLoop && loopNodeId != null) {
      items.add(
        _item('Fine Ciclo', FontAwesomeIcons.arrowRotateLeft, () {
          bloc.add(CloseLoop(
            fromNodeId: widget.sourceNodeId,
            loopNodeId: loopNodeId!,
          ));
        }),
      );
    } else {
      if (isSourceNodeLeaf && hasOtherLeafNodes && state is FlowchartLoaded && state.canAddOutgoingConnection(widget.sourceNodeId)) {
        items.add(
          _item('Connettore', FontAwesomeIcons.shareNodes, () {
            bloc.add(StartConnectorMode(widget.sourceNodeId));
          }),
        );
      }

      if (!isFunctionFlowchart) {
        items.add(
          _item('Fine', FontAwesomeIcons.flagCheckered,
              () => widget.onNodeCreate(FlowNodeKind.end)),
        );
      }
    }

    return items;
  }
}

class _SelectionBadge extends StatelessWidget {
  final bool isSource;
  const _SelectionBadge({this.isSource = false});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final Color bg = isSource ? theme.accentColor : Colors.green;
    final IconData icon = isSource ? FluentIcons.plug_connected : FluentIcons.check_mark;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

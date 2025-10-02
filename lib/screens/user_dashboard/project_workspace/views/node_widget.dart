import 'dart:async';
import 'dart:convert';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_repository/file_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flowchart_thesis/config/services/dialog_service/app_dialogs.dart';
import 'package:flowchart_thesis/blocs/file_bloc/file_system_bloc.dart';
import 'package:flowchart_thesis/blocs/file_bloc/file_system_state.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';
import 'painters.dart';

// Enum per la direzione delle maniglie di creazione
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

  // Costanti per il layout del widget e delle sue maniglie
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

  // Funzioni per mantenere il nodo all'interno dei bordi del canvas
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
          // Mostra le maniglie di creazione solo se il nodo è selezionato e non è in sola lettura
          ..._getAvailableHandles(context)
              .map((dir) => _buildCreationHandle(context, dir)),
        ],
      ),
    );
  }

  /// Costruisce una singola maniglia di creazione.
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

  /// Calcola la posizione centrale di una maniglia rispetto al nodo.
  Offset _getHandleCenter(HandleDirection direction) {
    const double bottomGap = 20.0;
    switch (direction) {
      case HandleDirection.bottom: return Offset(widget.node.width / 2, widget.node.height + bottomGap);
      case HandleDirection.top: return Offset(widget.node.width / 2, -gap);
      case HandleDirection.left: return Offset(-gap, widget.node.height / 2);
      case HandleDirection.right: return Offset(widget.node.width + gap, widget.node.height / 2);
    }
  }

  /// Determina quali maniglie di creazione mostrare in base al tipo di nodo e alle connessioni esistenti.
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
      case FlowNodeKind.end:
        return [];
      default:
        return state.canAddOutgoingConnection(widget.node.id)
            ? [HandleDirection.bottom]
            : [];
    }
  }

  /// Gestisce la creazione di un nuovo nodo a partire da un nodo esistente.
  void _createNode(BuildContext context, FlowNodeKind kind, String? fromPort) async {
    if (!mounted) return;
    final bloc = context.read<FlowchartBloc>();

    try {
      // ✨ ARCHITETTURA CORRETTA: DELEGA AL BLOC ✨
      // Per il nodo di Assegnazione, il widget non fa alcuna validazione.
      // Invia semplicemente un evento al BLoC, che gestirà tutta la logica complessa.
      if (kind == FlowNodeKind.assignment) {
        bloc.add(AssignmentNodeCreationRequested(
          fromNodeId: widget.node.id,
          fromPort: fromPort,
        ));
        // Il compito del widget per questo tipo di nodo è terminato.
        return;
      }

      // --- LOGICA LOCALE PER GLI ALTRI NODI (PIÙ SEMPLICI) ---
      final flowState = bloc.state;
      if (flowState is! FlowchartLoaded) return;

      if (kind == FlowNodeKind.end) {
        // ... (logica per il nodo 'Fine' invariata)
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

      // ✨ NOTA: Lo switch non ha bisogno di un caso 'assignment' perché è già gestito sopra.
      switch (kind) {
        case FlowNodeKind.input:
          final inputVariables = flowState.flowchart.variables.where((v) => v.scope == VariableScope.input).toList();
          if (inputVariables.isEmpty) {
            if (mounted) await AppDialogs.showInfoDialog(context, title: 'Nessuna Variabile di Input', message: 'Per creare un nodo di Input, devi prima dichiarare almeno una variabile come "Input".', type: DialogType.warning);
            return;
          }
          variablesForDialog = inputVariables;
          break;

        case FlowNodeKind.output:
          final outputVariables = flowState.flowchart.variables.where((v) => v.scope == VariableScope.output).toList();
          if (outputVariables.isEmpty) {
            if (mounted) await AppDialogs.showInfoDialog(context, title: 'Nessuna Variabile di Output', message: 'Per creare un nodo di Output, devi prima dichiarare almeno una variabile come "Output".', type: DialogType.warning);
            return;
          }
          variablesForDialog = outputVariables;
          break;

        case FlowNodeKind.process:
          final fsState = context.read<FileSystemBloc>().state;
          if (fsState is FileSystemLoaded) {
            filesForProcess = fsState.files.where((f) => f.fileId != fsState.activeFileId).toList();
          }
          variablesForDialog = flowState.flowchart.variables;
          break;

        default:
          variablesForDialog = flowState.flowchart.variables;
          break;
      }

      if (!mounted) return;
      final Map<String, dynamic>? nodeData = await AppDialogs.showNodeCreationDialog(
        context: context,
        kind: kind,
        files: filesForProcess,
        variables: variablesForDialog,
      );

      if (nodeData != null && mounted) {
        bloc.add(AddNode(
          kind: kind,
          fromNodeId: widget.node.id,
          fromPort: fromPort,
          canvasConstraints: widget.canvasConstraints,
          initialData: nodeData,
        ));
      }
    } catch (e) {
      debugPrint("Errore durante la creazione del nodo: $e");
    }
  }

  /// Risolve la porta di uscita per nodi speciali come 'Decisione'.
  String? _resolvePort(HandleDirection direction) {
    if (widget.node.kind == FlowNodeKind.decision) {
      return direction == HandleDirection.left ? 'false' : 'true';
    }
    return null;
  }
}

// --- WIDGET HELPER ---

/// Pulsante a forma di occhio per visualizzare i dettagli del nodo.
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
        backgroundColor: WidgetStateProperty.all(theme.cardColor.withOpacity(0.95)),
      ),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
        ),
        child: Center(
          child: Icon(FluentIcons.view, size: 18, color: theme.typography.body?.color),
        ),
      ),
    );
  }
}

/// Widget responsabile del rendering grafico del nodo.
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
          child: SizedBox(width: node.width, height: node.height, child: Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(node.text, textAlign: TextAlign.center, style: textStyle)))),
        );
        break;
      case FlowNodeKind.input:
      case FlowNodeKind.output:
        nodeContent = CustomPaint(
          painter: ParallelogramPainter(fillColor: fillColor, borderColor: borderColor, strokeWidth: borderWidth, reversed: node.kind == FlowNodeKind.output),
          child: SizedBox(width: node.width, height: node.height, child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis)))),
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
            boxShadow: [if (isSelected) BoxShadow(color: theme.accentColor.withOpacity(0.25), blurRadius: 8)],
          ),
          child: Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text(node.text, textAlign: TextAlign.center, style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis))),
        );
        break;
    }
    return nodeContent;
  }
}

/// Pulsante "+" che apre un menu a comparsa per la creazione di nuovi nodi.
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
            const double estimatedMenuHeight = 260.0;
            final double spaceBelow = widget.canvasConstraints.maxHeight - (widget.absolutePosition.dy + handleSize);
            final placement = spaceBelow >= estimatedMenuHeight ? FlyoutPlacementMode.bottomCenter : FlyoutPlacementMode.topCenter;

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
            color: theme.cardColor.withOpacity(0.95),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(FontAwesomeIcons.plus, size: 16, color: theme.typography.body?.color?.withOpacity(0.8)),
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
        leading: Icon(icon, size: 16, color: theme.typography.body?.color?.withOpacity(0.8)),
      );
    }

    return [
      buildItem('Input', FontAwesomeIcons.download, FlowNodeKind.input),
      buildItem('Assegnazione', FontAwesomeIcons.calculator, FlowNodeKind.assignment),
      buildItem('Output', FontAwesomeIcons.upload, FlowNodeKind.output),
      buildItem('Condizione', FontAwesomeIcons.codeBranch, FlowNodeKind.decision),
      buildItem('Sottoprogramma', FontAwesomeIcons.gears, FlowNodeKind.process),
      const MenuFlyoutSeparator(),
      buildItem('Fine', FontAwesomeIcons.flagCheckered, FlowNodeKind.end),
    ];
  }
}
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'node_widget.dart';
import 'painters.dart';
import 'node_creation_service.dart';

class FlowchartCanvas extends StatelessWidget {
  final bool showGrid;
  final bool isReadOnly;
  final bool allowDragInReadOnly;

  const FlowchartCanvas({
    super.key,
    required this.showGrid,
    this.isReadOnly = false,
    this.allowDragInReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<FlowchartBloc, FlowchartState>(
      listener: (context, state) {
        if (state is FlowchartActionFailure) {
          AppDialogs.showInfoDialog(
            context,
            title: state.title,
            message: state.message,
          );
        }
      },
      child: BlocBuilder<FlowchartBloc, FlowchartState>(
        builder: (context, state) {
          if (state is! FlowchartLoaded) {
            return const Center(child: ProgressRing());
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // FIX: Condiziono il comportamento del GestureDetector in base alla modalità connettore
              Widget canvasContent = GestureDetector(
                // Se siamo in modalità connettore O in debug, NON gestiamo i tap sulla canvas vuota
                onTap: (state.isConnectorModeActive || state.isDebugMode)
                    ? null
                    : () => context.read<FlowchartBloc>().add(const DeselectNode()),
                behavior: (state.isConnectorModeActive || state.isDebugMode)
                    ? HitTestBehavior.deferToChild
                    : HitTestBehavior.translucent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (showGrid)
                      Positioned.fill(
                        child:
                        CustomPaint(painter: GridPainter.fromTheme(context)),
                      ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ConnectionPainter(
                          nodes: state.flowchart.nodes,
                          edges: state.flowchart.edges,
                          theme: FluentTheme.of(context),
                        ),
                      ),
                    ),
                    for (final node in state.flowchart.nodes)
                      NodeWidget(
                        key: ValueKey(node.id),
                        node: node,
                        canvasConstraints: constraints,
                        isSelected: state.selectedNodeId == node.id &&
                            !state.isConnectorModeActive,
                        isReadOnly: isReadOnly,
                        allowDragInReadOnly: allowDragInReadOnly,
                      ),
                  ],
                ),
              );

              if (state.isDebugMode && state.selectedNodeId != null) {
                final node = state.getNodeById(state.selectedNodeId!);
                if (node != null) {
                  final viewportW = constraints.maxWidth;
                  final viewportH = constraints.maxHeight;
                  const double targetScale = 1.8;

                  final double nodeCenterX = node.x + node.width / 2;
                  final double nodeCenterY =
                      node.y + (node.height + 42.0) / 2;
                  final double targetTx =
                      (viewportW / 2) - nodeCenterX * targetScale;
                  final double targetTy =
                      (viewportH / 2) - nodeCenterY * targetScale;

                  // ⚠️ MODIFICA: Usa isDebugJustStarted invece di debugIndex == 0
                  final bool shouldZoom = state.isDebugJustStarted;

                  final double initialScale = shouldZoom ? 1.0 : targetScale;

                  canvasContent = ClipRect(
                    child: TweenAnimationBuilder<Offset>(
                      tween: Tween<Offset>(end: Offset(targetTx, targetTy)),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      key: ValueKey('dbg-offset-${state.selectedNodeId}'),
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: offset,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: initialScale, end: targetScale),
                            duration: shouldZoom
                                ? const Duration(milliseconds: 400)
                                : Duration.zero,
                            curve: Curves.easeInOut,
                            key: ValueKey(
                                'dbg-scale-${state.flowchart.flowchartId}'),
                            builder: (context, scale, grandChild) {
                              return Transform.scale(
                                scale: scale,
                                alignment: Alignment.topLeft,
                                child: grandChild,
                              );
                            },
                            child: child,
                          ),
                        );
                      },
                      child: canvasContent,
                    ),
                  );
                }
              }

              return Stack(
                children: [
                  canvasContent,
                  if (state.isConnectorModeActive)
                    _ConnectorOverlay(
                      state: state,
                      constraints: constraints,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ConnectorOverlay extends StatelessWidget {
  final FlowchartLoaded state;
  final BoxConstraints constraints;
  final FlyoutController _flyoutController = FlyoutController();

  _ConnectorOverlay({
    required this.state,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bloc = context.read<FlowchartBloc>();

    // ⚠️ NUOVO: Verifica se siamo in modalità selezione corpo do-while
    final sourceNode = state.connectorSourceNodeId != null
        ? state.getNodeById(state.connectorSourceNodeId!)
        : null;
    final isDoWhileBodySelection = sourceNode?.kind == FlowNodeKind.doWhileLoop ||
        state.connectorPurpose == ConnectorPurpose.doWhileBody;
    final isResetSelection = state.connectorPurpose == ConnectorPurpose.resetFromNode;

    // Per do-while/reset: l'utente deve selezionare UN SOLO nodo
    // Per connettore normale: almeno 2 nodi
    final hasSelection = state.selectedConnectorNodeIds.isNotEmpty;
    final canConfirm = isDoWhileBodySelection || isResetSelection
        ? state.selectedConnectorNodeIds.length == 1
        : state.selectedConnectorNodeIds.length >= 2;

    // Calcola il testo del bottone in base alla modalità
    final String buttonText = isDoWhileBodySelection
        ? (hasSelection ? 'Conferma selezione' : 'Seleziona il nodo di partenza del corpo')
        : (isResetSelection
            ? (hasSelection ? 'Conferma reset' : 'Seleziona il blocco finale')
            : (hasSelection
                ? 'Collega ${state.selectedConnectorNodeIds.length} nod${state.selectedConnectorNodeIds.length > 1 ? "i" : "o"}'
                : 'Seleziona nodi'));

    // Handler che apre i dialog di configurazione prima di creare il nodo
    Future<void> handleNodeTypeSelection(FlowNodeKind kind) async {
      _flyoutController.close();

      // Ottieni tutti i nodi sorgente selezionati per il contesto
      final sourceNodeIds = {
        state.connectorSourceNodeId!,
        ...state.selectedConnectorNodeIds
      };

      // Usa il servizio centralizzato per preparare la creazione del nodo
      final nodeData = await NodeCreationService.prepareNodeCreation(
        context: context,
        kind: kind,
        flowState: state,
        sourceNodeIds: sourceNodeIds,
      );

      if (nodeData == null) {
        // L'utente ha annullato il dialog o c'è stato un errore
        return;
      }

      // Crea il nodo con i dati configurati
      bloc.add(ApplyConnectorAndCreateNode(
        kind: kind,
        canvasConstraints: constraints,
        initialData: nodeData,
      ));
    }

    // ⚠️ NUOVO: Handler per confermare la selezione del corpo do-while
    void handleDoWhileBodyConfirm() {
      if (state.selectedConnectorNodeIds.isEmpty) return;

      final selectedNodeId = state.selectedConnectorNodeIds.first;
      bloc.add(SelectDoWhileBodyStart(
        doWhileNodeId: state.connectorSourceNodeId!,
        bodyStartNodeId: selectedNodeId,
      ));
    }

    // ✨ NUOVO: Handler per confermare il reset da blocco
    void handleResetFromNodeConfirm() {
      if (state.selectedConnectorNodeIds.isEmpty) return;
      final selectedNodeId = state.selectedConnectorNodeIds.first;
      bloc.add(ResetFromNode(selectedNodeId));
    }

    return Stack(
      children: [
        // Overlay semi-trasparente che NON blocca i click sui nodi
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              color: theme.micaBackgroundColor.withValues(alpha: 0.3),
            ),
          ),
        ),

        // ⚠️ NUOVO: Banner informativo in alto per do-while o reset
        if (isDoWhileBodySelection || isResetSelection)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      FluentIcons.info,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isDoWhileBodySelection
                          ? 'Seleziona il nodo di partenza del corpo del ciclo'
                          : 'Seleziona il blocco che diventerà l\'ultimo del flowchart',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Indicatori visivi sui nodi selezionati
        ...state.selectedConnectorNodeIds.map((nodeId) {
          final node = state.getNodeById(nodeId);
          if (node == null) return const SizedBox.shrink();

          return Positioned(
            left: node.x,
            top: node.y,
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Usa CustomPaint con il painter che segue la forma esatta del nodo
                  CustomPaint(
                    size: Size(node.width, node.height),
                    painter: NodeSelectionBorderPainter(
                      nodeKind: node.kind,
                      borderColor: theme.selectionColor,
                      strokeWidth: 4.0,
                    ),
                  ),
                  // Icona di spunta nell'angolo in alto a destra
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        FluentIcons.check_mark,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // ⚠️ MODIFICA: Controlli in basso AL CENTRO
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.resources.cardStrokeColorDefault),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Button(
                    onPressed: () => bloc.add(const CancelConnectorMode()),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.cancel, size: 16),
                        SizedBox(width: 8),
                        Text('Annulla'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ⚠️ MODIFICA: Bottone diverso per do-while vs connettore normale vs reset
                  if (isDoWhileBodySelection)
                    Opacity(
                      opacity: canConfirm ? 1.0 : 0.5,
                      child: FilledButton(
                        onPressed: canConfirm ? handleDoWhileBodyConfirm : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.check_mark, size: 16),
                            const SizedBox(width: 8),
                            Text(buttonText),
                          ],
                        ),
                      ),
                    )
                  else if (isResetSelection)
                    Opacity(
                      opacity: canConfirm ? 1.0 : 0.5,
                      child: FilledButton(
                        onPressed: canConfirm ? handleResetFromNodeConfirm : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.history, size: 16),
                            const SizedBox(width: 8),
                            Text(buttonText),
                          ],
                        ),
                      ),
                    )
                  else
                    FlyoutTarget(
                      controller: _flyoutController,
                      child: Opacity(
                        opacity: canConfirm ? 1.0 : 0.5,
                        child: FilledButton(
                          onPressed: canConfirm
                              ? () {
                                  _flyoutController.showFlyout(
                                    placementMode: FlyoutPlacementMode.bottomCenter,
                                    dismissOnPointerMoveAway: false,
                                    builder: (flyoutContext) {
                                      return MenuFlyout(
                                        items: [
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.input),
                                            text: const Text('Input'),
                                            leading: const FaIcon(FontAwesomeIcons.download, size: 16),
                                          ),
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.assignment),
                                            text: const Text('Assegnazione'),
                                            leading: const FaIcon(FontAwesomeIcons.calculator, size: 16),
                                          ),
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.output),
                                            text: const Text('Output'),
                                            leading: const FaIcon(FontAwesomeIcons.upload, size: 16),
                                          ),
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.decision),
                                            text: const Text('Condizione'),
                                            leading: const FaIcon(FontAwesomeIcons.codeBranch, size: 16),
                                          ),
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.process),
                                            text: const Text('Sottoprogramma'),
                                            leading: const FaIcon(FontAwesomeIcons.gears, size: 16),
                                          ),
                                          const MenuFlyoutSeparator(),
                                          MenuFlyoutItem(
                                            onPressed: () => handleNodeTypeSelection(FlowNodeKind.end),
                                            text: const Text('Fine'),
                                            leading: const FaIcon(FontAwesomeIcons.flagCheckered, size: 16),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FluentIcons.chevron_up, size: 16),
                              const SizedBox(width: 8),
                              Text(buttonText),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

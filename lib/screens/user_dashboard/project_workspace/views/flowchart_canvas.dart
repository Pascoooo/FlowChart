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
                // Se siamo in modalità connettore, NON gestiamo i tap sulla canvas
                onTap: state.isConnectorModeActive
                    ? null  // Disabilita completamente il tap in modalità connettore
                    : () => context.read<FlowchartBloc>().add(const DeselectNode()),
                behavior: state.isConnectorModeActive
                    ? HitTestBehavior.deferToChild  // Lascia che i figli gestiscano i click
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

                  final bool isFirstStep = state.debugIndex == 0;

                  final double initialScale = isFirstStep ? 1.0 : targetScale;

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
                            duration: isFirstStep
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
    final hasSelection = state.selectedConnectorNodeIds.isNotEmpty;

    // Calcola il testo del bottone
    final String buttonText = hasSelection
        ? 'Collega ${state.selectedConnectorNodeIds.length} nod${state.selectedConnectorNodeIds.length > 1 ? "i" : "o"}'
        : 'Seleziona nodi';

    // Handler che chiude il flyout e passa il tipo di nodo selezionato al BLoC
    void handleNodeTypeSelection(FlowNodeKind kind) {
      _flyoutController.close();
      // Passa al BLoC il tipo di nodo da creare e i nodi selezionati
      bloc.add(ApplyConnectorAndCreateNode(
        kind: kind,
        canvasConstraints: constraints,
        initialData: {}, // I dati verranno richiesti dal dialogo nel BLoC
      ));
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

        // Banner informativo in alto
        Positioned(
          top: 24,
          left: 24,
          right: 24,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentIcons.plug_connected,
                    color: theme.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Clicca sui nodi foglia (senza connessioni in uscita) per selezionarli',
                      style: theme.typography.body?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (hasSelection) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.selectedConnectorNodeIds.length}',
                        style: theme.typography.bodyStrong?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
            left: node.x - 8,
            top: node.y - 8,
            child: IgnorePointer(
              child: Container(
                width: node.width + 16,
                height: node.height + 16,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.accentColor,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: const Offset(8, -8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        FluentIcons.check_mark,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        // Controlli in basso - questi DEVONO essere cliccabili
        Positioned(
          bottom: 80,
          right: 24,
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
                FlyoutTarget(
                  controller: _flyoutController,
                  child: FilledButton(
                    onPressed: hasSelection
                        ? () {
                            _flyoutController.showFlyout(
                              placementMode: FlyoutPlacementMode.topRight,
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
                        const Icon(FluentIcons.completed_solid, size: 16),
                        const SizedBox(width: 8),
                        Text(buttonText),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

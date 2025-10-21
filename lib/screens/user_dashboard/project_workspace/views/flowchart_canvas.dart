import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../blocs/debug_bloc/debug_bloc_exports.dart';
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
          // Log in console invece di mostrare un dialogo
          debugPrint('Flowchart error: \\n- ${state.title}: ${state.message}');
        }
      },
      child: BlocListener<DebugBloc, DebugState>(
        // ✅ NUOVO: Listener per gestire la selezione del nodo iniziale quando parte il debug
        listener: (context, debugState) {
          if (debugState is DebugInProgress && debugState.isFirstStep) {
            // Seleziona automaticamente il nodo iniziale
            final flowchartBloc = context.read<FlowchartBloc>();
            final flowchartState = flowchartBloc.state;
            if (flowchartState is FlowchartLoaded) {
              final id = debugState.currentNodeId;
              if (id.isEmpty) return; // Guard: indice -1 non ha nodo corrente
              debugPrint('🎯 Auto-selezione nodo iniziale: $id');
              flowchartBloc.add(SelectNode(id));
            }
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
                  // Se siamo in modalità connettore, NON gestiamo i tap sulla canvas vuota
                  onTap: state.isConnectorModeActive
                      ? null
                      : () {
                          // Evita di deselezionare durante il debug (previene de-zoom)
                          final dbg = context.read<DebugBloc>().state;
                          final isInDebugTap = dbg is DebugInProgress ||
                              dbg is DebugAwaitingInput ||
                              dbg is DebugError ||
                              dbg is DebugCompleted;
                          if (isInDebugTap) return;
                          context.read<FlowchartBloc>().add(const DeselectNode());
                        },
                  behavior: state.isConnectorModeActive
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
                          isSelected: (!state.isConnectorModeActive && state.selectedNodeId == node.id) ||
                              (state.isConnectorModeActive && state.connectorSourceNodeId == node.id),
                          isReadOnly: isReadOnly,
                          allowDragInReadOnly: allowDragInReadOnly,
                        ),

                      // Overlay guida per selezione corpo do-while
                      if (state.isConnectorModeActive && state.connectorPurpose == ConnectorPurpose.doWhileBody)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child:  _DoWhileSelectionBanner(),
                        ),

                      // Overlay guida per modalità Reset da nodo
                      if (state.isConnectorModeActive && state.connectorPurpose == ConnectorPurpose.resetFromNode)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: const _ResetSelectionBanner(),
                        ),

                      // 🆕 NUOVO: Overlay guida per modalità chiusura ciclo
                      if (state.isConnectorModeActive && state.connectorPurpose == ConnectorPurpose.loopClosure)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: _LoopClosureBanner(
                            loopNodeId: state.connectorSourceNodeId!,
                            canvasConstraints: constraints,
                          ),
                        ),

                      // Overlay guida per modalità Connettore normale
                      if (state.isConnectorModeActive && state.connectorPurpose == ConnectorPurpose.normal)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: _ConnectorModeBanner(canvasConstraints: constraints),
                        ),
                    ],
                  ),
                );

                // Usa il DebugBloc per verificare se siamo in modalità debug
                final debugState = context.watch<DebugBloc>().state;
                final isInDebug = debugState is DebugInProgress ||
                    debugState is DebugAwaitingInput ||
                    debugState is DebugError ||
                    debugState is DebugCompleted;

                // ✅ FIXED: Gestione corretta dello zoom e pan in debug mode
                if (isInDebug && state.selectedNodeId != null) {
                  final node = state.getNodeById(state.selectedNodeId!);
                  if (node != null) {
                    final viewportW = constraints.maxWidth;
                    final viewportH = constraints.maxHeight;

                    // Determina se dobbiamo eseguire l'animazione di zoom (solo al primo step)
                    final shouldAnimateZoom = debugState is DebugInProgress && debugState.isFirstStep;
                    final targetScale = shouldAnimateZoom ? 1.5 : 1.5; // Mantieni lo stesso zoom

                    final double nodeCenterX = node.x + node.width / 2;
                    final double nodeCenterY = node.y + node.height / 2;
                    final double targetTx = (viewportW / 2) - (nodeCenterX * targetScale);
                    final double targetTy = (viewportH / 2) - (nodeCenterY * targetScale);

                    canvasContent = ClipRect(
                      child: TweenAnimationBuilder<Matrix4>(
                        // Rimosso key dinamico che resettava l'animazione tra step
                        tween: Matrix4Tween(
                          begin: shouldAnimateZoom
                              ? Matrix4.identity()
                              : null, // null => usa valore corrente
                          end: Matrix4.translationValues(targetTx, targetTy, 0)..scale(targetScale),
                        ),
                        duration: shouldAnimateZoom
                            ? const Duration(milliseconds: 600)
                            : const Duration(milliseconds: 400),
                        curve: shouldAnimateZoom ? Curves.easeOutCubic : Curves.easeInOutCubic,
                        onEnd: () {
                          if (shouldAnimateZoom) {
                            debugPrint('✅ Zoom iniziale completato, reset flag isFirstStep');
                            context.read<DebugBloc>().add(const DebugResetFirstStep());
                          }
                        },
                        builder: (context, transform, child) {
                          return Transform(
                            transform: transform,
                            child: child,
                          );
                        },
                        child: canvasContent,
                      ),
                    );
                  }
                }

                return canvasContent;
              },
            );
          },
        ),
      ),
    );
  }
}

class _DoWhileSelectionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.info_solid, color: theme.accentColor, size: 16),
            const SizedBox(width: 8),
            Text(
              'Seleziona il blocco che sarà l\'inizio del corpo del ciclo do-while. Suggerimento: clicca su un altro rombo do-while per cambiare sorgente.',
              style: theme.typography.body,
            ),
            const SizedBox(width: 12),
            Button(
              onPressed: () {
                final fcState = context.read<FlowchartBloc>().state;
                if (fcState is FlowchartLoaded) {
                  final srcId = fcState.connectorSourceNodeId;
                  if (srcId != null) {
                    // Rimuovi il nodo do-while non completato
                    context.read<FlowchartBloc>().add(RemoveNode(srcId));
                  }
                  // Chiudi comunque la modalità selezione
                  context.read<FlowchartBloc>().add(const CancelConnectorMode());
                } else {
                  context.read<FlowchartBloc>().add(const CancelConnectorMode());
                }
              },
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetSelectionBanner extends StatelessWidget {
  const _ResetSelectionBanner();
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BlocBuilder<FlowchartBloc, FlowchartState>(
          builder: (context, state) {
            final loaded = state is FlowchartLoaded ? state : null;
            final selectedCount = loaded?.selectedConnectorNodeIds.length ?? 0;
            final canConfirm = selectedCount == 1;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.info_solid, color: theme.accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  canConfirm
                      ? 'Premi Conferma per resettare dal nodo selezionato.'
                      : 'Seleziona un nodo (non Inizio/intestazione) da cui resettare il diagramma.',
                  style: theme.typography.body,
                ),
                const SizedBox(width: 12),
                Button(
                  onPressed: () => context.read<FlowchartBloc>().add(const CancelConnectorMode()),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          final id = loaded!.selectedConnectorNodeIds.first;
                          context.read<FlowchartBloc>().add(ResetFromNode(id));
                        }
                      : null,
                  child: const Text('Conferma'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectorModeBanner extends StatelessWidget {
  final BoxConstraints canvasConstraints;
  const _ConnectorModeBanner({required this.canvasConstraints});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BlocBuilder<FlowchartBloc, FlowchartState>(
          builder: (context, state) {
            final loaded = state as FlowchartLoaded;
            final count = loaded.selectedConnectorNodeIds.length;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.info_solid, color: theme.accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  count == 0
                      ? 'Seleziona uno o più nodi foglia da connettere a un nuovo blocco.'
                      : 'Selezionati: $count nodi. Crea il nuovo blocco per connetterli.',
                  style: theme.typography.body,
                ),
                const SizedBox(width: 12),
                Button(
                  onPressed: () => context.read<FlowchartBloc>().add(const CancelConnectorMode()),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await _showCreateNodeDialog(context, loaded);
                  },
                  child: const Text('Crea nodo…'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateNodeDialog(BuildContext context, FlowchartLoaded state) async {
    final isFunctionFlowchart = state.flowchart.isFunction;

    final kinds = <Map<String, dynamic>>[
      {'label': 'Input', 'kind': FlowNodeKind.input, 'icon': FontAwesomeIcons.download},
      {'label': 'Assegnazione', 'kind': FlowNodeKind.assignment, 'icon': FontAwesomeIcons.calculator},
      {'label': 'Output', 'kind': FlowNodeKind.output, 'icon': FontAwesomeIcons.upload},
      {'label': 'Condizione', 'kind': FlowNodeKind.decision, 'icon': FontAwesomeIcons.codeBranch},
      {'label': 'Sottoprogramma', 'kind': FlowNodeKind.process, 'icon': FontAwesomeIcons.gears},
      {'label': 'Ciclo Pre-Condizionale', 'kind': FlowNodeKind.whileLoop, 'icon': FontAwesomeIcons.arrowsRotate},
      {'label': 'Ciclo Post-Condizionale', 'kind': FlowNodeKind.doWhileLoop, 'icon': FontAwesomeIcons.repeat},
      if (isFunctionFlowchart)
        {'label': 'Return', 'kind': FlowNodeKind.returnNode, 'icon': FontAwesomeIcons.reply}
    ];

    FlowNodeKind? selectedKind;

    await showDialog(
      context: context,
      builder: (ctx) {
        return ContentDialog(
          title: const Text('Scegli il tipo di nodo da creare'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in kinds)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Button(
                      onPressed: () {
                        selectedKind = item['kind'] as FlowNodeKind;
                        Navigator.of(ctx).pop();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item['icon'] as IconData, size: 16),
                          const SizedBox(width: 8),
                          Text(item['label'] as String),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annulla'),
            ),
          ],
        );
      },
    );

    if (selectedKind == null) return;

    // Raccogli i dati necessari per il nodo scelto
    final initialData = await NodeCreationService.prepareNodeCreation(
      context: context,
      kind: selectedKind!,
      flowState: state,
      sourceNodeIds: {if (state.connectorSourceNodeId != null) state.connectorSourceNodeId!, ...state.selectedConnectorNodeIds},
    );

    // Dispatch creazione connettore + nuovo nodo
    context.read<FlowchartBloc>().add(ApplyConnectorAndCreateNode(
      kind: selectedKind!,
      canvasConstraints: canvasConstraints,
      initialData: initialData,
    ));
  }
}

class _LoopClosureBanner extends StatelessWidget {
  final String loopNodeId;
  final BoxConstraints canvasConstraints;

  const _LoopClosureBanner({
    required this.loopNodeId,
    required this.canvasConstraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.resources.cardStrokeColorDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: BlocBuilder<FlowchartBloc, FlowchartState>(
          builder: (context, state) {
            final loaded = state is FlowchartLoaded ? state : null;
            final selectedCount = loaded?.selectedConnectorNodeIds.length ?? 0;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.info_solid, color: theme.accentColor, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    selectedCount == 0
                        ? 'Seleziona nodi foglia da connettere, o crea nuovi blocchi.'
                        : 'Selezionati: $selectedCount nodi. Crea blocchi, chiudi il ciclo o continua.',
                    style: theme.typography.body,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Button(
                  onPressed: () => context.read<FlowchartBloc>().add(const CancelConnectorMode()),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 8),
                // Pulsante per creare nuovi blocchi (identico al connettore normale)
                FilledButton(
                  onPressed: () async {
                    await _showCreateNodeDialogForLoop(context, loaded!);
                  },
                  child: const Text('Crea Blocco…'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateNodeDialogForLoop(BuildContext context, FlowchartLoaded state) async {
    final isFunctionFlowchart = state.flowchart.isFunction;

    final kinds = <Map<String, dynamic>>[
      {'label': 'Input', 'kind': FlowNodeKind.input, 'icon': FontAwesomeIcons.download},
      {'label': 'Assegnazione', 'kind': FlowNodeKind.assignment, 'icon': FontAwesomeIcons.calculator},
      {'label': 'Output', 'kind': FlowNodeKind.output, 'icon': FontAwesomeIcons.upload},
      {'label': 'Condizione', 'kind': FlowNodeKind.decision, 'icon': FontAwesomeIcons.codeBranch},
      {'label': 'Sottoprogramma', 'kind': FlowNodeKind.process, 'icon': FontAwesomeIcons.gears},
      {'label': 'Ciclo Pre-Condizionale', 'kind': FlowNodeKind.whileLoop, 'icon': FontAwesomeIcons.arrowsRotate},
      {'label': 'Ciclo Post-Condizionale', 'kind': FlowNodeKind.doWhileLoop, 'icon': FontAwesomeIcons.repeat},
      if (isFunctionFlowchart)
        {'label': 'Return', 'kind': FlowNodeKind.returnNode, 'icon': FontAwesomeIcons.reply}
    ];

    FlowNodeKind? selectedKind;
    bool closeLoop = false;

    // ✅ MODIFICA: Il dialogo ora restituisce un bool? (true=azione, false/null=annulla)
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ContentDialog(
          title: const Text('Scegli il tipo di blocco da creare'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in kinds)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Button(
                      onPressed: () {
                        selectedKind = item['kind'] as FlowNodeKind;
                        // ✅ MODIFICA: Restituisce true per confermare
                        Navigator.of(ctx).pop(true);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item['icon'] as IconData, size: 16),
                          const SizedBox(width: 8),
                          Text(item['label'] as String),
                        ],
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(),
                ),
                // 🎯 Opzione "Fine Ciclo"
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Button(
                    onPressed: state.selectedConnectorNodeIds.length >= 2
                        ? () {
                      closeLoop = true;
                      // ✅ MODIFICA: Restituisce true per confermare
                      Navigator.of(ctx).pop(true);
                    }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FontAwesomeIcons.arrowRotateLeft, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          state.selectedConnectorNodeIds.length >= 2
                              ? 'Fine Ciclo'
                              : 'Fine Ciclo (seleziona almeno 2 nodi)',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () {
                // ✅ MODIFICA: Restituisce false per annullare
                Navigator.of(ctx).pop(false);
              },
              child: const Text('Annulla'),
            ),
          ],
        );
      },
    );

    // ✅ MODIFICA: Controlla il risultato del dialogo
    // Se l'utente ha premuto "Annulla" (o chiuso il dialogo), esci E annulla la modalità connettore
    if (result == null || result == false) {
      if (!context.mounted) return;
      // Questa è l'azione che mancava:
      context.read<FlowchartBloc>().add(const CancelConnectorMode());
      return;
    }

    // --- Da qui in poi, il codice viene eseguito solo se result == true ---

    // Se l'utente ha scelto "Fine Ciclo"
    if (closeLoop) {
      if (!context.mounted) return;
      context.read<FlowchartBloc>().add(ApplyLoopClosure(loopNodeId));
      return;
    }

    // Se l'utente ha scelto un tipo di nodo (selectedKind non sarà null)
    if (selectedKind == null) {
      // Questo non dovrebbe accadere se result è true e closeLoop è false,
      // ma è una sicurezza in più.
      if (!context.mounted) return;
      context.read<FlowchartBloc>().add(const CancelConnectorMode());
      return;
    }

    // Raccogli i dati necessari per il nodo scelto
    final initialData = await NodeCreationService.prepareNodeCreation(
      context: context,
      kind: selectedKind!,
      flowState: state,
      sourceNodeIds: {if (state.connectorSourceNodeId != null) state.connectorSourceNodeId!, ...state.selectedConnectorNodeIds},
    );

    if (!context.mounted) return;
    // Dispatch creazione connettore + nuovo nodo
    context.read<FlowchartBloc>().add(ApplyConnectorAndCreateNode(
      kind: selectedKind!,
      canvasConstraints: canvasConstraints,
      initialData: initialData,
    ));
  }
}
/// Debug mode view orchestrating console, variables panel, and step-by-step execution.
/// Features resizable panels, automatic grid state preservation, and file snapshot restoration.
/// Integrates debug console, session variables, and work area for comprehensive debugging experience.
import 'package:file_repository/file_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/debug_bloc/debug_bloc.dart';
import '../../../../blocs/debug_bloc/debug_event.dart';
import '../../../../blocs/debug_bloc/debug_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import 'debug_console/debug_console_widget.dart';
import 'debug_mode/debug_step_info_card.dart';
import 'debug_mode/session_variables_panel.dart';
import 'workarea.dart';

/// 🐛 Debug Mode View - Modalità di debug con validazione runtime
class DebugModeView extends StatefulWidget {
  final GlobalKey workareaKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;

  const DebugModeView({
    super.key,
    required this.workareaKey,
    required this.showGrid,
    required this.onToggleGrid,
  });

  @override
  State<DebugModeView> createState() => _DebugModeViewState();
}

class _DebugModeViewState extends State<DebugModeView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  double _consoleHeight = 280.0;
  bool _isDraggingDivider = false;
  double _rightPanelWidth = 0.4;
  bool _isDraggingHorizontalDivider = false;

  // ✅ NUOVO: Salva lo stato della griglia all'ingresso e lo ripristina all'uscita
  bool _gridStateOnEnter = false;

  // ✅ NUOVO: snapshot del file attivo all'ingresso della debug mode
  String? _entryFileId;
  String? _entryFileName;
  String? _entryFileContent;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Salva lo stato iniziale della griglia
    _gridStateOnEnter = widget.showGrid;

    // 🔒 Cattura il file attivo corrente per poter ripristinare il canvas all'uscita dal debug
    final fsState = context.read<FileSystemBloc>().state;
    if (fsState is FileSystemLoaded) {
      final activeId = fsState.activeFileId;
      if (activeId != null) {
        final file = fsState.files.firstWhere(
          (f) => f.fileId == activeId,
          orElse: () => MyFile.empty,
        );
        if (file != MyFile.empty) {
          _entryFileId = file.fileId;
          _entryFileName = file.name;
          _entryFileContent = file.content;
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocListener<DebugBloc, DebugState>(
      // ✅ FIXED: Selezione automatica del nodo corrente quando si avanza/retrocede
      listener: (context, state) {
        // NUOVO: sincronizza il flag di debug nel FlowchartBloc
        final flowchartBloc = context.read<FlowchartBloc>();
        if (state is DebugInProgress || state is DebugAwaitingInput) {
          flowchartBloc.add(const SetDebugMode(true));
        } else if (state is DebugInitial || state is DebugCompleted) {
          flowchartBloc.add(const SetDebugMode(false));
        }

        // 🔄 NUOVO: quando entri/esci da un sottoprogramma, carica il flowchart corrente del DebugBloc nel canvas
        if (state is DebugInProgress) {
          final fcState = flowchartBloc.state;
          // Aggiorna il flowchart mostrato se differente
          if (fcState is FlowchartLoaded && fcState.flowchart.flowchartId != state.currentFlowchart.flowchartId) {
            flowchartBloc.add(UpdateFlowchart(state.currentFlowchart));
          }

          // Calcola l'ID da selezionare: se currentIndex < 0, seleziona il primo del path (entry del callee)
          String selectionId = '';
          if (state.session.currentIndex >= 0) {
            selectionId = state.currentNodeId;
          } else {
            if (state.session.debugPath.isNotEmpty) {
              selectionId = state.session.debugPath.first;
            }
          }
          if (selectionId.isNotEmpty) {
            final refreshed = flowchartBloc.state;
            if (refreshed is FlowchartLoaded && refreshed.selectedNodeId != selectionId) {
              debugPrint('🎯 Auto-selezione: $selectionId');
              flowchartBloc.add(SelectNode(selectionId));
            }
          }
        } else if (state is DebugAwaitingInput) {
          final fcState = flowchartBloc.state;
          if (fcState is FlowchartLoaded && fcState.flowchart.flowchartId != state.currentFlowchart.flowchartId) {
            flowchartBloc.add(UpdateFlowchart(state.currentFlowchart));
          }

          // Calcola l'ID da selezionare anche in attesa input
          String selectionId = '';
          if (state.session.currentIndex >= 0) {
            selectionId = state.currentNodeId;
          } else {
            if (state.session.debugPath.isNotEmpty) {
              selectionId = state.session.debugPath.first;
            }
          }
          if (selectionId.isNotEmpty) {
            final refreshed = flowchartBloc.state;
            if (refreshed is FlowchartLoaded && refreshed.selectedNodeId != selectionId) {
              debugPrint('🎯 Auto-selezione (await): $selectionId');
              flowchartBloc.add(SelectNode(selectionId));
            }
          }
        } else if (state is DebugInitial || state is DebugCompleted) {
          // Ripristina lo stato della griglia quando si esce dalla modalità debug (sia con stop che con completamento)
          if (widget.showGrid != _gridStateOnEnter) {
            widget.onToggleGrid();
          }

          // ✅ NUOVO: Ripristina il flowchart del file originale (es. main) all'uscita
          // Preferisci lo snapshot catturato all'ingresso; in fallback usa lo stato attuale del FileSystem
          final savedId = _entryFileId;
          final savedName = _entryFileName;
          final savedContent = _entryFileContent;
          if (savedId != null && savedName != null && savedContent != null) {
            flowchartBloc.add(LoadFlowchart(
              jsonContent: savedContent,
              fileName: savedName,
              fileId: savedId,
            ));
          } else {
            final fs = context.read<FileSystemBloc>().state;
            if (fs is FileSystemLoaded) {
              final activeId = fs.activeFileId;
              if (activeId != null) {
                final file = fs.files.firstWhere(
                  (f) => f.fileId == activeId,
                  orElse: () => MyFile.empty,
                );
                if (file != MyFile.empty) {
                  flowchartBloc.add(LoadFlowchart(
                    jsonContent: file.content,
                    fileName: file.name,
                    fileId: file.fileId,
                  ));
                }
              }
            }
          }
        }
      },
      child: FadeTransition(
        opacity: _fade,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final rightWidth = totalWidth * _rightPanelWidth;
            final leftWidth = totalWidth - rightWidth - 8;

            return Stack(
              children: [
                Row(
                  children: [
                // Colonna sinistra - WorkArea + Console
                SizedBox(
                  width: leftWidth,
                  child: Column(
                    children: [
                      // WorkArea sopra
                      Expanded(
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: WorkArea(
                                repaintKey: widget.workareaKey,
                                showGrid: widget.showGrid,
                                onToggleGrid: widget.onToggleGrid,
                                isReadOnly: true,
                                allowDragInReadOnly: false,
                              ),
                            ),

                            // Top Left - Step Info Card
                            const Positioned(
                              top: 24,
                              left: 24,
                              child: DebugStepInfoCard(),
                            ),

                            // Top Right - chiusura debug
                            Positioned(
                              top: 16,
                              right: 16,
                              child: IconButton(
                                icon: const Icon(FluentIcons.chrome_close, size: 30),
                                onPressed: () {
                                  context.read<DebugBloc>().add(const DebugStop());
                                },
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(const EdgeInsets.all(10)),
                                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                                  shape: WidgetStateProperty.all(const CircleBorder()),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 16,
                              top: 0,
                              bottom: 0,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward, size: 40),
                                    onPressed: () {
                                      context.read<DebugBloc>().add(const DebugPrevious());
                                    },
                                    style: ButtonStyle(
                                      padding: WidgetStateProperty.all(const EdgeInsets.all(14)),
                                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                                      shape: WidgetStateProperty.all(const CircleBorder()),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward, size: 40),
                                    onPressed: () {
                                      context.read<DebugBloc>().add(const DebugNext());
                                    },
                                    style: ButtonStyle(
                                      padding: WidgetStateProperty.all(const EdgeInsets.all(14)),
                                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                                      shape: WidgetStateProperty.all(const CircleBorder()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divisore verticale ridimensionabile
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            setState(() {
                              _consoleHeight = (_consoleHeight - details.delta.dy).clamp(150.0, 500.0);
                            });
                          },
                          onVerticalDragStart: (_) {
                            setState(() => _isDraggingDivider = true);
                          },
                          onVerticalDragEnd: (_) {
                            setState(() => _isDraggingDivider = false);
                          },
                          child: Container(
                            height: 8,
                            color: _isDraggingDivider
                                ? theme.accentColor.withValues(alpha: 0.3)
                                : theme.resources.dividerStrokeColorDefault,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.resources.textFillColorTertiary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Console interattiva sotto (SEMPRE DISPONIBILE per navigazione e comandi)
                      BlocBuilder<DebugBloc, DebugState>(
                        builder: (context, debugState) {
                          // ✅ Mostra la console in tutti gli stati di debug
                          final showConsole = debugState is DebugInProgress ||
                              debugState is DebugAwaitingInput ||
                              debugState is DebugError ||
                              debugState is DebugCompleted;
                          if (!showConsole) {
                            return const SizedBox.shrink();
                          }

                          // Se siamo in stato DebugCompleted, mostra un messaggio
                          if (debugState is DebugCompleted) {
                            return SizedBox(
                              height: _consoleHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.resources.layerFillColorDefault,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        FluentIcons.completed,
                                        size: 48,
                                        color: theme.accentColor,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        debugState.message,
                                        style: theme.typography.subtitle?.copyWith(
                                          color: theme.accentColor,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton(
                                        onPressed: () {
                                          context.read<DebugBloc>().add(const DebugStop());
                                        },
                                        child: const Text('Chiudi Debug'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          // Ottieni il flowchart corrente dal FlowchartBloc
                          final flowchartState = context.read<FlowchartBloc>().state;
                          if (flowchartState is! FlowchartLoaded) {
                            return const SizedBox.shrink();
                          }

                          // In caso di errore, mostra comunque la console senza richiedere il nodo corrente.
                          if (debugState is DebugError) {
                            return SizedBox(
                              height: _consoleHeight,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.resources.layerFillColorDefault,
                                ),
                                child: const DebugConsole(),
                              ),
                            );
                          }

                          // Per InProgress/AwaitingInput: usa il nodo corrente per inizializzare la console
                          String? currentNodeId;
                          if (debugState is DebugInProgress) {
                            currentNodeId = debugState.currentNodeId;
                          } else if (debugState is DebugAwaitingInput) {
                            currentNodeId = debugState.currentNodeId;
                          }

                          // Mostra SEMPRE la console anche se currentNodeId è vuoto (es. appena entrati in sottoprogramma con index -1)
                          return SizedBox(
                            height: _consoleHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.resources.layerFillColorDefault,
                              ),
                              child: const DebugConsole(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Divisore orizzontale ridimensionabile
                MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final delta = details.delta.dx / totalWidth;
                        _rightPanelWidth = (_rightPanelWidth - delta).clamp(0.2, 0.6);
                      });
                    },
                    onHorizontalDragStart: (_) {
                      setState(() => _isDraggingHorizontalDivider = true);
                    },
                    onHorizontalDragEnd: (_) {
                      setState(() => _isDraggingHorizontalDivider = false);
                    },
                    child: Container(
                      width: 8,
                      color: _isDraggingHorizontalDivider
                          ? theme.accentColor.withValues(alpha: 0.3)
                          : theme.resources.dividerStrokeColorDefault,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.resources.textFillColorTertiary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Colonna destra - Variabili di Sessione
                SizedBox(
                  width: rightWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.resources.layerFillColorAlt,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SessionVariablesPanel(),
                    ),
                  ),
                ),
              ],
            ),

          ],
        );
          },
        ),
      ),
    );
  }
}

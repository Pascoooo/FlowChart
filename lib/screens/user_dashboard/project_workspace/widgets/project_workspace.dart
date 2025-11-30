/// Main project workspace orchestrating sidebar, work area, and debug mode views.
/// Handles export functionality, debug session initiation, and animated view transitions.
/// Integrates with FileSystemBloc, FlowchartBloc, and DebugBloc for comprehensive project management.
import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:debug_repository/debug_repository.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../blocs/debug_bloc/debug_bloc.dart';
import '../../../../blocs/debug_bloc/debug_event.dart';
import '../../../../blocs/debug_bloc/debug_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../config/services/banner_service.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';
import '../../../../config/services/export_service.dart';
import '../../../settings/widgets/settings_provider.dart';
import '../views/debug_mode_view.dart';
import '../views/workarea.dart';


class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;
  final bool isReadOnly;
  final VoidCallback? onLeave;
  const ProjectWorkspace(
      {super.key,
        required this.selectedProject,
        this.isReadOnly = false,
        this.onLeave});

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace>
    with TickerProviderStateMixin {
  final GlobalKey _workareaKey = GlobalKey();
  late AnimationController _slideInController;
  late Animation<Offset> _sidebarSlideAnimation;
  late Animation<Offset> _workareaSlideAnimation;
  late Animation<double> _workareaScaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _showGrid = true;
  bool? _preDebugShowGrid;

  Timer? _debounce;
  StreamSubscription? _rtdbSubscription;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _slideInController.forward();
  }

  void _initAnimations() {
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _sidebarSlideAnimation =
        Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideInController, curve: Curves.easeOutCubic));
    _workareaSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideInController, curve: Curves.easeOutCubic));
    _workareaScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(parent: _slideInController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _slideInController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeIn)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _rtdbSubscription?.cancel();
    _slideInController.dispose();
    super.dispose();
  }

  String _getCurrentFileName(FileSystemLoaded state) {
    if (state.activeFileId != null && state.files.isNotEmpty) {
      final matchingFile = state.files.firstWhere(
            (f) => f.fileId == state.activeFileId,
        orElse: () => state.files.first,
      );
      return matchingFile.name.replaceAll(' ', '_').toLowerCase();
    }
    return 'unichart_diagram';
  }

  Future<void> _handleExport(BuildContext innerContext) async {
    if (!mounted || !(innerContext.mounted)) return;
    final fileState = innerContext.read<FileSystemBloc>().state;
    if (fileState is FileSystemLoaded && fileState.activeFileId != null) {
      final fileName = _getCurrentFileName(fileState);
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes == null) {
        if (mounted && innerContext.mounted) {
          BannerService.showError(innerContext, "Errore durante la creazione dell'immagine.");
        }
        return;
      }
    } else {
      if (!mounted || !(innerContext.mounted)) return;
      await AppDialogs.showInfoDialog(innerContext, title: "Nessun File Selezionato", message: "Seleziona un file prima di esportare.");
    }
  }

  // ==========================================================================
  // 🎬 AVVIO DEBUG (Semplificato - Solo Evento al BLoC)
  // ==========================================================================

  /// Gestisce l'avvio della modalità debug.
  /// ✨ REFACTORING CRITICO: Questo metodo è stato drasticamente semplificato.
  /// La UI ora si limita a:
  /// 1. Verificare che gli stati siano pronti
  /// 2. Preparare i dati necessari (flowcharts)
  /// 3. Inviare un evento al DebugBloc
  ///
  /// Tutta la logica di business (costruzione del path, validazione, ecc.)
  /// è stata spostata nel DebugBloc dove appartiene.
  void _handleStartDebug(BuildContext ctx) async {
    if (!mounted || !ctx.mounted) return;

    final flowchartBloc = ctx.read<FlowchartBloc>();
    final flowchartState = flowchartBloc.state;
    if (flowchartState is! FlowchartLoaded) {
      BannerService.showError(ctx, 'Impossibile avviare il debug: flowchart non caricato.');
      return;
    }

    final fileSystemBloc = ctx.read<FileSystemBloc>();
    final fileSystemState = fileSystemBloc.state;
    if (fileSystemState is! FileSystemLoaded) {
      BannerService.showError(ctx, 'Impossibile avviare il debug: file system non pronto.');
      return;
    }

    // Salva lo stato corrente della griglia
    _preDebugShowGrid ??= _showGrid;
    if (_showGrid) {
      final settings = ctx.read<SettingsProvider>();
      if (!settings.dontShowGridDialogAgain) {
        final result = await GenericDialogs.showGridWarningDialog(ctx);
        if (result == null) {
          return;
        }
        if (result['dontShowAgain'] == true) {
          settings.setDontShowGridDialogAgain(true);
        }
      }
      if (!mounted) return;
      setState(() => _showGrid = false);
    }

    // 1️⃣ Serializza il flowchart corrente nel cache
    if (fileSystemState.activeFileId != null) {
      try {
        final serialized = flowchartState.toJson();
        if (serialized.trim().isNotEmpty) {
          fileSystemBloc.add(UpdateFileContentInCache(
            fileId: fileSystemState.activeFileId!,
            newContent: serialized,
          ));
        }
      } catch (e) {
        debugPrint('⚠️ Impossibile serializzare il flowchart: $e');
      }
    }

    // 2️⃣ Prepara tutti i flowchart del progetto
    final Map<String, Flowchart> allFlowcharts = {};
    for (final file in fileSystemState.files) {
      try {
        if (file.content.trim().isNotEmpty) {
          final entity = FlowchartEntity.fromDocument(jsonDecode(file.content));
          final flowchart = Flowchart.fromEntity(entity);
          allFlowcharts[flowchart.name] = flowchart;
        }
      } catch (e) {
        debugPrint('⚠️ Impossibile parsare file ${file.name}: $e');
      }
    }

    // Usa sempre la versione IN MEMORIA del flowchart corrente
    final String currentName = flowchartState.flowchart.name;
    allFlowcharts[currentName] = flowchartState.flowchart; // override prima
    final Flowchart mainFlowchart = flowchartState.flowchart; // sempre in memoria

    if (allFlowcharts.isNotEmpty) {
      flowchartBloc.add(LoadProjectFlowcharts(allFlowcharts));
    }

    try {
      // 3️⃣ ✨ UNICO PUNTO DI INTERAZIONE CON IL DEBUGBLOC
      ctx.read<DebugBloc>().add(DebugStart(
        flowchart: mainFlowchart,
        projectFlowcharts: allFlowcharts.isNotEmpty
            ? allFlowcharts
            : {currentName: mainFlowchart},
      ));

      debugPrint('✅ Evento DebugStart inviato al BLoC');
    } catch (e) {
      debugPrint('❌ Errore avvio debug: $e');
      BannerService.showError(ctx, 'Errore avvio debug: $e');

      // Ripristina la griglia in caso di errore
      if (_preDebugShowGrid != null) {
        setState(() {
          _showGrid = _preDebugShowGrid!;
          _preDebugShowGrid = null;
        });
      }
    }
  }

  // ============================================================================
  // ❌ METODO RIMOSSO: _buildDebugPath()
  //
  // Questo metodo conteneva logica di business pura (attraversamento del grafo)
  // ed è stato spostato nel DebugBloc come metodo privato.
  //
  // La UI NON deve sapere come si costruisce un percorso di debug.
  // ============================================================================

  @override
  Widget build(BuildContext outerContext) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: MultiBlocProvider(
        providers: [
          BlocProvider<FlowchartBloc>(
            create: (context) => FlowchartBloc(),
          ),
          BlocProvider<FileSystemBloc>(
            key: ValueKey('filesystem-${widget.selectedProject.projectId}'),
            create: (context) => FileSystemBloc(
              projectRepository: context.read<ProjectBloc>().projectRepository,
            )..add(RefreshFileSystem(projectId: widget.selectedProject.projectId)),
          ),
        ],
        child: BlocBuilder<FileSystemBloc, FileSystemState>(
          builder: (context, fileSystemState) {
            // Usa solo il numero di file per la chiave, non il contenuto
            // così il DebugBloc non viene ricreato durante le modifiche
            int fileCount = 0;
            if (fileSystemState is FileSystemLoaded) {
              fileCount = fileSystemState.files.length;
            }
            return BlocProvider<DebugBloc>(
              key: ValueKey('debug-${widget.selectedProject.projectId}-$fileCount'),
              create: (context) {
                Map<String, Flowchart> projectFlowcharts = {};
                if (fileSystemState is FileSystemLoaded) {
                  for (final file in fileSystemState.files) {
                    try {
                      if (file.content.trim().isNotEmpty) {
                        final entity = FlowchartEntity.fromDocument(jsonDecode(file.content));
                        final flowchart = Flowchart.fromEntity(entity);
                        projectFlowcharts[flowchart.name] = flowchart;
                      }
                    } catch (e) {
                      debugPrint('Could not parse file ${file.name} for debug context: $e');
                    }
                  }
                }
                return DebugBloc(
                  debugRepository: DebugRepoImpl(projectFlowcharts: projectFlowcharts),
                );
              },
              child: MultiBlocListener(
                listeners: [
                  BlocListener<FileSystemBloc, FileSystemState>(
                    listenWhen: (prev, curr) =>
                    prev is! FileSystemLoaded && curr is FileSystemLoaded,
                    listener: (context, state) {
                      if (!mounted || !(context.mounted)) return; // guardia contro contesto deattivato
                      if (state is FileSystemLoaded) {
                        final Map<String, Flowchart> projectFlowcharts = {};
                        for (final file in state.files) {
                          try {
                            if (file.content.trim().isNotEmpty) {
                              final entity = FlowchartEntity.fromDocument(jsonDecode(file.content));
                              final flowchart = Flowchart.fromEntity(entity);
                              projectFlowcharts[flowchart.name] = flowchart;
                            }
                          } catch (e) {
                            debugPrint('Could not parse file ${file.name} for debug context: $e');
                          }
                        }
                        if (projectFlowcharts.isNotEmpty) {
                          context.read<FlowchartBloc>().add(LoadProjectFlowcharts(projectFlowcharts));
                        }
                      }
                    },
                  ),

                  BlocListener<DebugBloc, DebugState>(
                    listener: (context, debugState) {
                      if (!mounted || !(context.mounted)) return; // guardia contro contesto deattivato
                      final flowchartBloc = context.read<FlowchartBloc>();
                      final flowchartState = flowchartBloc.state;

                      if (debugState is DebugInitial) {
                        // Debug terminato manualmente
                        if (flowchartState is FlowchartLoaded) {
                          // 🔴 FIX: Rimosso clearDebugVariables - il DebugBloc gestisce già la pulizia
                          // tramite endSession() quando riceve DebugStop

                          if (_preDebugShowGrid != null) {
                            setState(() {
                              _showGrid = _preDebugShowGrid!;
                              _preDebugShowGrid = null;
                            });
                          }
                        }
                      } else if (debugState is DebugCompleted) {
                        // ✅ Debug terminato raggiungendo la fine: ripristina come per DebugInitial
                        if (flowchartState is FlowchartLoaded) {
                          // 🔴 FIX: Rimosso clearDebugVariables - il DebugBloc gestisce già la pulizia
                          // tramite endSession() quando riceve DebugStop

                          if (_preDebugShowGrid != null) {
                            setState(() {
                              _showGrid = _preDebugShowGrid!;
                              _preDebugShowGrid = null;
                            });
                          }
                        }
                        // Porta il DebugBloc allo stato iniziale per pulire la sessione del repo
                        context.read<DebugBloc>().add(const DebugStop());
                      }
                      // 🔴 FIX CRITICO: Rimosso else if con ComputeDebugStep
                      // Il DebugBloc gestisce autonomamente l'avanzamento tramite executeNextStep()
                      // Non c'è bisogno di notificare il FileSystemBloc
                    },
                  ),
                  // ==========================================================
                  // 💾 SALVATAGGIO FLOWCHART: usa FlowchartBloc.activeFileId
                  // ==========================================================
                  BlocListener<FlowchartBloc, FlowchartState>(
                    listenWhen: (previous, current) {
                      // Salva solo quando il flowchart cambia e NON siamo in debug
                      // Per verificare se siamo in debug, usiamo il DebugBloc
                      return previous is! FlowchartLoaded && current is FlowchartLoaded ||
                          (previous is FlowchartLoaded && current is FlowchartLoaded &&
                              previous.flowchart != current.flowchart);
                    },
                    listener: (context, state) {
                      if (!mounted || !(context.mounted)) return; // guardia contro contesto deattivato
                      // Controlla se siamo in debug dal DebugBloc
                      final debugState = context.read<DebugBloc>().state;
                      final isInDebug = debugState is DebugInProgress || debugState is DebugAwaitingInput;

                      if (state is FlowchartLoaded && !widget.isReadOnly && !isInDebug) {
                        // ✅ Usa FlowchartBloc come source of truth
                        final flowchartBlocRef = context.read<FlowchartBloc>();
                        final activeFileId = flowchartBlocRef.activeFileId;
                        if (activeFileId == null) return;

                        final fileSystemState = context.read<FileSystemBloc>().state;
                        if (fileSystemState is! FileSystemLoaded) return;

                        // Validazione extra: il file deve esistere nella lista
                        final activeFile = fileSystemState.files.firstWhereOrNull((f) => f.fileId == activeFileId);
                        if (activeFile == null) return;

                        final jsonContent = state.toJson();
                        if (jsonContent.trim().isEmpty) return;

                        _debounce?.cancel();
                        final projectRepo = context.read<ProjectBloc>().projectRepository;
                        final projectId = widget.selectedProject.projectId;
                        _debounce = Timer(const Duration(milliseconds: 400), () {
                          if (!mounted) return;
                          projectRepo.updateLiveFileContent(
                            projectId,
                            activeFileId,
                            jsonContent,
                          );
                        });
                      }
                    },
                  ),

                  // ==========================================================
                  // ✨ LISTENER CORRETTO E AGGIORNATO PER IL CAMBIO FILE
                  // ==========================================================
                  BlocListener<FileSystemBloc, FileSystemState>(
                    listener: (context, state) async {
                      if (!mounted || !(context.mounted)) return; // guardia contro contesto deattivato
                      // Cattura riferimenti stabili ai bloc/repo per evitare context.read() dopo await o in callback
                      final projectRepo = context.read<ProjectBloc>().projectRepository;
                      final fileSystemBlocRef = context.read<FileSystemBloc>();
                      final flowchartBlocRef = context.read<FlowchartBloc>();
                      final debugBlocRef = context.read<DebugBloc>();

                      if (state is FileSystemError) {
                        BannerService.showError(context, state.message);
                        return;
                      }

                      if (state is! FileSystemLoaded) return;

                      // ✅ Usa FlowchartBloc come source of truth per il file precedente
                      final previousFlowchartFileId = flowchartBlocRef.activeFileId;

                      // Hai cambiato file nel FileSystemBloc?
                      if (previousFlowchartFileId != state.activeFileId) {
                        debugPrint('🔄 Cambio file: "$previousFlowchartFileId" → "${state.activeFileId}"');

                        // STEP 1: Salva il file precedente
                        if (previousFlowchartFileId != null) {
                          _debounce?.cancel();

                          final flowchartState = flowchartBlocRef.state;
                          if (flowchartState is FlowchartLoaded && !widget.isReadOnly) {
                            final jsonContent = flowchartState.toJson();

                            if (jsonContent.trim().isNotEmpty) {
                              debugPrint('💾 Salvataggio file precedente: $previousFlowchartFileId');

                              try {
                                await projectRepo.updateLiveFileContent(
                                  widget.selectedProject.projectId,
                                  previousFlowchartFileId,
                                  jsonContent,
                                );

                                fileSystemBlocRef.add(UpdateFileContentInCache(
                                  fileId: previousFlowchartFileId,
                                  newContent: jsonContent,
                                ));
                              } catch (e) {
                                debugPrint('❌ Errore salvataggio: $e');
                              }
                            }
                          }
                        }

                        // STEP 2: Carica il nuovo file
                        await _rtdbSubscription?.cancel();

                        if (state.activeFileId == null && state.files.isNotEmpty) {
                          final mainFile = state.files.firstWhere(
                            (f) => f.name.toLowerCase() == 'main',
                            orElse: () => state.files.first,
                          );
                          fileSystemBlocRef.add(OpenFile(
                            projectId: widget.selectedProject.projectId,
                            fileId: mainFile.fileId,
                          ));
                          return;
                        }

                        if (state.activeFileId != null) {
                          final activeFile = state.files.firstWhereOrNull(
                            (f) => f.fileId == state.activeFileId,
                          );

                          if (activeFile != null) {
                            debugPrint('📥 Caricamento nuovo file: ${activeFile.name}');

                            flowchartBlocRef.add(LoadFlowchart(
                              fileId: activeFile.fileId,
                              jsonContent: activeFile.content,
                              fileName: activeFile.name,
                            ));

                            // Setup live updates
                            if (!widget.isReadOnly) {
                              final projectId = widget.selectedProject.projectId;
                              final fileId = activeFile.fileId;
                              final fileName = activeFile.name;

                              _rtdbSubscription = projectRepo
                                  .liveFileContent(projectId, fileId)
                                  .listen((liveContent) {
                                if (!mounted) return;
                                if (liveContent == null || liveContent.trim().isEmpty) return;

                                // Verifica che il FlowchartBloc abbia lo stesso fileId
                                if (flowchartBlocRef.activeFileId != fileId) {
                                  debugPrint('⚠️ Ignorando update: file diverso');
                                  return;
                                }

                                final currentFcState = flowchartBlocRef.state;
                                if (currentFcState is FlowchartLoaded) {
                                  try {
                                    final currentJson = currentFcState.toJson();
                                    if (const DeepCollectionEquality().equals(
                                        jsonDecode(liveContent),
                                        jsonDecode(currentJson))) {
                                      return;
                                    }
                                  } catch (_) {}
                                }

                                final debugState = debugBlocRef.state;
                                final isInDebug = debugState is DebugInProgress || debugState is DebugAwaitingInput;

                                if (isInDebug) return;
                                if (FlowchartLoaded.tryParse(liveContent) == null) return;

                                flowchartBlocRef.add(LoadFlowchart(
                                  fileId: fileId,
                                  jsonContent: liveContent,
                                  fileName: fileName,
                                ));
                              });
                            }
                          }
                        }
                      }
                    },
                  ),

                  BlocListener<FlowchartBloc, FlowchartState>(
                    listenWhen: (prev, curr) => curr is ShowNodeCreationDialog,
                    listener: (context, state) async {
                      if (!mounted || !(context.mounted)) return; // guardia contro contesto deattivato
                      if (state is ShowNodeCreationDialog) {
                        final data = await AppDialogs.showNodeCreationDialog(
                          context: context,
                          kind: state.kind,
                          variables: state.availableVariables,
                        );
                        if (data == null || !mounted || !(context.mounted)) return; // ricontrolla dopo l'await

                        final ctx = _workareaKey.currentContext;
                        BoxConstraints canvasConstraints;
                        if (ctx != null && ctx.findRenderObject() is RenderBox) {
                          final renderBox = ctx.findRenderObject() as RenderBox;
                          canvasConstraints = BoxConstraints.tight(renderBox.size);
                        } else {
                          final size = MediaQuery.sizeOf(context);
                          canvasConstraints = BoxConstraints.loose(size);
                        }

                        context.read<FlowchartBloc>().add(AddNode(
                          kind: state.kind,
                          fromNodeId: state.fromNodeId,
                          fromPort: state.fromPort,
                          canvasConstraints: canvasConstraints,
                          initialData: data,
                        ));
                      }
                    },
                  ),
                ],
                child: BlocBuilder<DebugBloc, DebugState>(
                  builder: (ctx, debugState) {
                    // Mostra DebugModeView se siamo in una sessione di debug attiva
                    if (debugState is DebugInProgress || debugState is DebugAwaitingInput || debugState is DebugError || debugState is DebugCompleted) {
                      return DebugModeView(
                        workareaKey: _workareaKey,
                        showGrid: _showGrid,
                        onToggleGrid: () { if (!mounted) return; setState(() => _showGrid = !_showGrid); },
                      );
                    }
                    return AnimatedBuilder(
                      animation: _slideInController,
                      builder: (innerContext, child) {
                        return _WorkspaceLayout(
                          sidebarSlideAnimation: _sidebarSlideAnimation,
                          workareaSlideAnimation: _workareaSlideAnimation,
                          workareaScaleAnimation: _workareaScaleAnimation,
                          fadeAnimation: _fadeAnimation,
                          selectedProject: widget.selectedProject,
                          workareaKey: _workareaKey,
                          onExport: () => _handleExport(innerContext),
                          showGrid: _showGrid,
                          toggleGrid: () { if (!mounted) return; setState(() => _showGrid = !_showGrid); },
                          onStartDebug: () => _handleStartDebug(innerContext),
                          isReadOnly: widget.isReadOnly,
                          onLeave: widget.onLeave,
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class _WorkspaceLayout extends StatelessWidget {
  final Animation<Offset> sidebarSlideAnimation;
  final Animation<Offset> workareaSlideAnimation;
  final Animation<double> workareaScaleAnimation;
  final Animation<double> fadeAnimation;
  final MyProject selectedProject;
  final GlobalKey workareaKey;
  final VoidCallback onExport;
  final bool showGrid;
  final VoidCallback toggleGrid;
  final VoidCallback onStartDebug;
  final bool isReadOnly;
  final VoidCallback? onLeave;

  const _WorkspaceLayout({
    required this.sidebarSlideAnimation,
    required this.workareaSlideAnimation,
    required this.workareaScaleAnimation,
    required this.fadeAnimation,
    required this.selectedProject,
    required this.workareaKey,
    required this.onExport,
    required this.showGrid,
    required this.toggleGrid,
    required this.onStartDebug,
    required this.isReadOnly,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SlideTransition(
          position: sidebarSlideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ProjectSidebar(
                selectedProject: selectedProject, isReadOnly: isReadOnly),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0, bottom: 16.0, top: 16.0),
            child: SlideTransition(
              position: workareaSlideAnimation,
              child: ScaleTransition(
                scale: workareaScaleAnimation,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: WorkArea(
                    repaintKey: workareaKey,
                    showGrid: showGrid,
                    onToggleGrid: toggleGrid,
                    isReadOnly: isReadOnly,
                    onExport: onExport,
                    onStartDebug: onStartDebug,
                    onLeave: onLeave,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

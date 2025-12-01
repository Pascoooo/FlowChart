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
import '../../../../blocs/ai_chat_bloc/ai_chat_bloc.dart';
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
import '../../../../config/services/gemini_service.dart';
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

  // 🆕 Flag per prevenire loop infiniti nel cambio file
  bool _isChangingFile = false;

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
    if (!mounted || !innerContext.mounted) return;
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
      
      if (mounted && innerContext.mounted) {
        await ExportService.downloadFileWithDialog(
          context: innerContext,
          bytes: pngBytes,
          fileName: fileName,
        );
      }
    } else {
      if (!mounted || !innerContext.mounted) return;
      await AppDialogs.showInfoDialog(innerContext, title: "Nessun File Selezionato", message: "Seleziona un file prima di esportare.");
    }
  }

  // ==========================================================================
  // 🆕 METODO HELPER PER RIPRISTINARE LA GRIGLIA
  // ==========================================================================
  void _restoreGridState() {
    if (_preDebugShowGrid != null && mounted) {
      setState(() {
        _showGrid = _preDebugShowGrid!;
        _preDebugShowGrid = null;
      });
    }
  }

  // ==========================================================================
  // 🎬 AVVIO DEBUG (Refactored con gestione errori migliorata)
  // ==========================================================================

  /// Gestisce l'avvio della modalità debug.
  /// Verifica gli stati, prepara i dati e invia l'evento al DebugBloc.
  /// Con gestione robusta degli errori e salvataggi.
  Future<void> _handleStartDebug(BuildContext ctx) async {
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

    // 🔒 Precarica il main in cache senza cambiare il file attivo, così lo snapshot è aggiornato
    final mainFile = fileSystemState.files.firstWhereOrNull(
          (f) => f.name.toLowerCase() == 'main',
    );
    if (mainFile != null && flowchartBloc.activeFileId != mainFile.fileId) {
      flowchartBloc.add(PreloadFlowchartCache(
        fileId: mainFile.fileId,
        fileName: mainFile.name,
        jsonContent: mainFile.content,
      ));
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

    // 1️⃣ Salvataggio forzato di tutti i flowchart in memoria (attivo + cache)
    final projectRepo = ctx.read<ProjectBloc>().projectRepository;
    final cacheSnapshot = flowchartBloc.exportAllFlowcharts();
    final savedFlowchartsByFileId = <String, Flowchart>{};

    for (final entry in cacheSnapshot.entries) {
      final fileId = entry.key;
      final targetFile = fileSystemState.files.firstWhereOrNull((f) => f.fileId == fileId);
      if (targetFile == null) continue;

      final normalizedFlowchart = entry.value.copyWith(name: targetFile.name);
      final serialized = jsonEncode(normalizedFlowchart.toEntity().toDocument());

      savedFlowchartsByFileId[fileId] = normalizedFlowchart;

      fileSystemBloc.add(UpdateFileContentInCache(
        fileId: fileId,
        newContent: serialized,
      ));

      try {
        await projectRepo.updateLiveFileContent(
          widget.selectedProject.projectId,
          fileId,
          serialized,
        );
      } catch (e) {
        debugPrint('⚠️ Errore salvataggio forzato ($fileId): $e');
        if (mounted && ctx.mounted) {
          BannerService.showError(ctx, 'Avviso: impossibile salvare "${targetFile.name}" prima dell\'esecuzione.');
        }
      }
    }

    // 2️⃣ Prepara i flowchart del progetto usando le versioni salvate in cache
    // e, se necessario, il contenuto già presente nel file system.
    final Flowchart mainFlowchart = flowchartState.flowchart;
    final Map<String, Flowchart> allFlowcharts = {};

    for (final file in fileSystemState.files) {
      Flowchart? flowchart = savedFlowchartsByFileId[file.fileId];

      if (flowchart == null && file.fileId == flowchartBloc.activeFileId) {
        flowchart = mainFlowchart;
      }

      if (flowchart == null && file.content.trim().isNotEmpty) {
        try {
          final entity = FlowchartEntity.fromDocument(jsonDecode(file.content));
          flowchart = Flowchart.fromEntity(entity);
        } catch (e) {
          debugPrint('⚠️ Impossibile parsare file ${file.name}: $e');
        }
      }

      if (flowchart != null) {
        final normalized = flowchart.copyWith(name: file.name);
        allFlowcharts.putIfAbsent(normalized.name, () => normalized);
      }
    }

    // Aggiorna il FlowchartBloc con tutti i flowchart del progetto
    if (allFlowcharts.length > 1) {
      flowchartBloc.add(LoadProjectFlowcharts(allFlowcharts));
    }

    // 3️⃣ Avvia il debug
    try {
      if (!mounted || !ctx.mounted) return;

      ctx.read<DebugBloc>().add(DebugStart(
        flowchart: mainFlowchart,
        projectFlowcharts: allFlowcharts,
      ));

      debugPrint('✅ Evento DebugStart inviato al BLoC');
    } catch (e) {
      debugPrint('❌ Errore avvio debug: $e');
      if (mounted && ctx.mounted) {
        BannerService.showError(ctx, 'Errore avvio debug: $e');
        _restoreGridState();
      }
    }
  }

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
          BlocProvider<AiChatBloc>(
            create: (context) => AiChatBloc(
              apiKey: GeminiService.instance.apiKey ?? '',
            ),
          ),
        ],
        child: BlocBuilder<FileSystemBloc, FileSystemState>(
          builder: (context, fileSystemState) {
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
                      if (!mounted || !context.mounted) return;
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

                  // ==========================================================
                  // 🆕 LISTENER DEBUG STATE - LOGICA UNIFICATA
                  // ==========================================================
                  BlocListener<DebugBloc, DebugState>(
                    listener: (context, debugState) {
                      if (!mounted || !context.mounted) return;

                      // 🆕 Gestione unificata del termine debug
                      if (debugState is DebugInitial || debugState is DebugCompleted) {
                        _restoreGridState();

                        // 💾 SALVA SU FIRESTORE ALL'USCITA DAL DEBUG (solo se NON in modalità read-only)
                        if (!widget.isReadOnly) {
                          final projectRepo = context.read<ProjectBloc>().projectRepository;
                          unawaited(projectRepo.saveSessionToFirestore(
                              widget.selectedProject.projectId
                          ));
                        }

                        // Se DebugCompleted, invia DebugStop per pulire il repository
                        if (debugState is DebugCompleted) {
                          // Usa un microtask per evitare modifiche durante il build
                          Future.microtask(() {
                            if (mounted && context.mounted) {
                              context.read<DebugBloc>().add(const DebugStop());
                            }
                          });
                        }
                      }
                    },
                  ),

                  // ==========================================================
                  // 💾 SALVATAGGIO FLOWCHART - CORRETTO
                  // ==========================================================
                  BlocListener<FlowchartBloc, FlowchartState>(
                    listenWhen: (previous, current) {
                      // 🆕 Condizione con parentesi esplicite per chiarezza
                      return (previous is! FlowchartLoaded && current is FlowchartLoaded) ||
                          (previous is FlowchartLoaded &&
                              current is FlowchartLoaded &&
                              previous.flowchart != current.flowchart);
                    },
                    listener: (context, state) {
                      if (!mounted || !context.mounted) return;

                      // Verifica se siamo in debug
                      final debugState = context.read<DebugBloc>().state;
                      final isInDebug = debugState is DebugInProgress ||
                          debugState is DebugAwaitingInput;

                      if (state is FlowchartLoaded && !widget.isReadOnly && !isInDebug) {
                        final flowchartBlocRef = context.read<FlowchartBloc>();
                        final activeFileId = flowchartBlocRef.activeFileId;
                        if (activeFileId == null) return;

                        final fileSystemState = context.read<FileSystemBloc>().state;
                        if (fileSystemState is! FileSystemLoaded) return;

                        final activeFile = fileSystemState.files.firstWhereOrNull(
                                (f) => f.fileId == activeFileId
                        );
                        if (activeFile == null) return;

                        final jsonContent = state.toJson();
                        if (jsonContent.trim().isEmpty) return;

                        // 🆕 Cancella il timer precedente prima di crearne uno nuovo
                        _debounce?.cancel();

                        final projectRepo = context.read<ProjectBloc>().projectRepository;
                        final projectId = widget.selectedProject.projectId;

                        _debounce = Timer(const Duration(milliseconds: 400), () {
                          if (!mounted) return;
                          // Fire-and-forget: non bloccare l'UI
                          unawaited(projectRepo.updateLiveFileContent(
                            projectId,
                            activeFileId,
                            jsonContent,
                          ));
                        });
                      }
                    },
                  ),

                  // ==========================================================
                  // 🆕 CAMBIO FILE - CON PROTEZIONE LOOP INFINITI
                  // ==========================================================
                  BlocListener<FileSystemBloc, FileSystemState>(
                    listener: (context, state) async {
                      if (!mounted || !context.mounted) return;

                      // 🆕 Previeni loop infiniti
                      if (_isChangingFile) {
                        debugPrint('⚠️ Cambio file già in corso, ignoro evento');
                        return;
                      }

                      final projectRepo = context.read<ProjectBloc>().projectRepository;
                      final fileSystemBlocRef = context.read<FileSystemBloc>();
                      final flowchartBlocRef = context.read<FlowchartBloc>();

                      if (state is FileSystemError) {
                        BannerService.showError(context, state.message);
                        return;
                      }

                      if (state is! FileSystemLoaded) return;

                      final previousFlowchartFileId = flowchartBlocRef.activeFileId;

                      if (previousFlowchartFileId != state.activeFileId) {
                        debugPrint('🔄 Cambio file: "$previousFlowchartFileId" → "${state.activeFileId}"');

                        // 🆕 Attiva il flag
                        _isChangingFile = true;

                        try {
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

                                  if (!mounted || !context.mounted) return;

                                  fileSystemBlocRef.add(UpdateFileContentInCache(
                                    fileId: previousFlowchartFileId,
                                    newContent: jsonContent,
                                  ));
                                } catch (e) {
                                  debugPrint('❌ Errore salvataggio: $e');
                                  // Continua comunque con il caricamento del nuovo file
                                }
                              }
                            }
                          }

                          // STEP 2: Gestisci file non selezionato
                          if (state.activeFileId == null && state.files.isNotEmpty) {
                            final mainFile = state.files.firstWhere(
                                  (f) => f.name.toLowerCase() == 'main',
                              orElse: () => state.files.first,
                            );

                            if (!mounted || !context.mounted) return;

                            fileSystemBlocRef.add(OpenFile(
                              projectId: widget.selectedProject.projectId,
                              fileId: mainFile.fileId,
                            ));
                            return;
                          }

                          // STEP 3: Carica il nuovo file
                          if (state.activeFileId != null) {
                            final activeFile = state.files.firstWhereOrNull(
                                  (f) => f.fileId == state.activeFileId,
                            );

                            if (activeFile != null) {
                              debugPrint('📥 Caricamento nuovo file: ${activeFile.name}');

                              if (!mounted || !context.mounted) return;

                              flowchartBlocRef.add(LoadFlowchart(
                                fileId: activeFile.fileId,
                                jsonContent: activeFile.content,
                                fileName: activeFile.name,
                              ));
                            }
                          }
                        } finally {
                          // 🆕 Rilascia il flag dopo un breve delay per garantire stabilità
                          Future.delayed(const Duration(milliseconds: 100), () {
                            _isChangingFile = false;
                          });
                        }
                      }
                    },
                  ),

                  // ==========================================================
                  // DIALOG CREAZIONE NODI
                  // ==========================================================
                  BlocListener<FlowchartBloc, FlowchartState>(
                    listenWhen: (prev, curr) => curr is ShowNodeCreationDialog,
                    listener: (context, state) async {
                      if (!mounted || !context.mounted) return;

                      if (state is ShowNodeCreationDialog) {
                        final data = await AppDialogs.showNodeCreationDialog(
                          context: context,
                          kind: state.kind,
                          variables: state.availableVariables,
                        );

                        if (data == null || !mounted || !context.mounted) return;

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
                    // Mostra DebugModeView se siamo in debug
                    if (debugState is DebugInProgress ||
                        debugState is DebugAwaitingInput ||
                        debugState is DebugError ||
                        debugState is DebugCompleted) {
                      return DebugModeView(
                        workareaKey: _workareaKey,
                        showGrid: _showGrid,
                        onToggleGrid: () {
                          if (!mounted) return;
                          setState(() => _showGrid = !_showGrid);
                        },
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
                          toggleGrid: () {
                            if (!mounted) return;
                            setState(() => _showGrid = !_showGrid);
                          },
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
              selectedProject: selectedProject,
              isReadOnly: isReadOnly,
              onLeave: onLeave,
            ),
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

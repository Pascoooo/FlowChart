import 'dart:async';
import 'dart:convert';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/topbar.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_event.dart';
import '../../../../blocs/auth_bloc/authentication_state.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../config/services/banner_service.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/export_service.dart';
import '../../../settings/widgets/settings_provider.dart';
import '../views/workarea.dart';
import '../../../../config/services/dialog_service/service_dialog.dart';


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
  late Animation<Offset> _topbarSlideAnimation;
  late Animation<Offset> _workareaSlideAnimation;
  late Animation<double> _workareaScaleAnimation;
  late Animation<double> _fadeAnimation;

  // Variabili di stato
  bool _showGrid = true;
  bool _dontShowGridDialogAgain = false;
  bool? _preDebugShowGrid;

  Timer? _debounce;
  StreamSubscription? _rtdbSubscription;
  String? _lastRtdbContent;
  String? _currentFileId;

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
    _topbarSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
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

  void _onEdit() async {
    try {
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes != null) {
        final b64 = base64Encode(pngBytes);
        html.window.localStorage['editor_last_screenshot'] = b64;
      }
    } catch (_) {}
    final String path = Uri.base.toString().split('#')[0];
    final Uri url = Uri.parse('$path#/drawing-editor');
    html.WindowBase popup =
    html.window.open(url.toString(), 'editor', 'width=1200,height=800');
    if (popup.closed ?? true) {
      BannerService.showError(
          context, 'Popup bloccati. Abilita i popup per continuare.');
    }
  }

  Future<void> _handleExport(BuildContext innerContext) async {
    final fileState = innerContext.read<FileSystemBloc>().state;
    if (fileState is FileSystemLoaded && fileState.activeFileId != null) {
      final fileName = _getCurrentFileName(fileState);
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes == null) {
        if (mounted) {
          BannerService.showError(context, "Errore durante la creazione dell'immagine.");
        }
        return;
      }
      final settingsProvider = innerContext.read<SettingsProvider>();
      final authState = innerContext.read<AuthenticationBloc>().state;
      final exportPreference = settingsProvider.exportPreference;

      switch (exportPreference) {
        case ExportPreference.local:
          await ExportService.downloadFileWithDialog(context: innerContext, bytes: pngBytes, fileName: fileName);
          break;
        case ExportPreference.drive:
          if (authState.user.driveConnected) {
            innerContext.read<AuthenticationBloc>().add(ExportFlowchartToDriveRequested(fileName: '$fileName.png', fileBytes: pngBytes));
          } else {
            await AppDialogs.showExportLocationDialog(context: innerContext, pngBytes: pngBytes, fileName: fileName);
          }
          break;
        case ExportPreference.alwaysAsk:
          await AppDialogs.showExportLocationDialog(context: innerContext, pngBytes: pngBytes, fileName: fileName);
          break;
      }
    } else {
      if (!mounted) return;
      await AppDialogs.showInfoDialog(innerContext, title: "Nessun File Selezionato", message: "Seleziona un file prima di esportare.");
    }
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  // Handler per avviare il debug
  void _handleStartDebug(BuildContext context) async {
    setState(() {
      _preDebugShowGrid = _showGrid;
      _showGrid = false;
    });

    if (_preDebugShowGrid == true && !_dontShowGridDialogAgain) {
      await GenericDialogs.showInfoWithRememberDialog(
        context,
        title: "Modalità Debug",
        message: "La griglia è stata disattivata per una migliore visibilità. Verrà ripristinata all'uscita dalla modalità debug.",
        onRememberPreference: (bool value) {
          setState(() {
            _dontShowGridDialogAgain = value;
          });
        },
      );
    }

    final flowchartBloc = context.read<FlowchartBloc>();
    final fileSystemBloc = context.read<FileSystemBloc>();
    final flowchartState = flowchartBloc.state;

    if (flowchartState is FlowchartLoaded) {
      fileSystemBloc.add(StartDebugSession(flowchart: flowchartState.flowchart));
      flowchartBloc.add(const DebugFlowchart());
    }
  }

  // Gestione aggiunta variabile usando il contesto che contiene i Bloc (providerCtx)
  void _handleAddVariable(BuildContext providerCtx, VariableScope scope) async {
    final flowchartState = providerCtx.read<FlowchartBloc>().state;

    final existing = flowchartState is FlowchartLoaded
        ? flowchartState.flowchart.variables
        : <VariableDeclaration>[];

    final newVariable = await AppDialogs.showAddVariableDialog(
      context: providerCtx,
      existingDeclarations: existing,
      defaultScope: scope,
    );

    if (newVariable != null && mounted) {
      if (flowchartState is FlowchartLoaded) {
        providerCtx.read<FlowchartBloc>().add(AddGlobalVariable(newVariable));
      } else {
        AppDialogs.showInfoDialog(
          providerCtx,
          title: 'Flowchart non pronto',
          message:
              'La variabile è stata definita ma il flowchart non è ancora disponibile. Riprova quando il flowchart è caricato.',
          type: DialogType.warning,
        );
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
        ],
        child: MultiBlocListener(
          listeners: [
            // Listener per la logica di DEBUG (avanzamento step e uscita)
            BlocListener<FlowchartBloc, FlowchartState>(
              listenWhen: (prev, curr) {
                if (prev is FlowchartLoaded && curr is FlowchartLoaded) {
                  return prev.isDebugMode != curr.isDebugMode || prev.debugIndex != curr.debugIndex;
                }
                return false;
              },
              listener: (context, state) {
                if (state is! FlowchartLoaded) return;
                final fileSystemBloc = context.read<FileSystemBloc>();
                final flowchart = state.flowchart;

                if (!state.isDebugMode) {
                  fileSystemBloc.add(EndDebugSession(projectId: flowchart.flowchartId));
                  if (_preDebugShowGrid != null) {
                    setState(() {
                      _showGrid = _preDebugShowGrid!;
                      _preDebugShowGrid = null;
                    });
                  }
                } else {
                  fileSystemBloc.add(ComputeDebugStep(
                    index: state.debugIndex,
                    debugPath: state.debugPath,
                    flowchart: flowchart,
                  ));
                }
              },
            ),
            // Listener per l'EXPORT su Google Drive
            BlocListener<AuthenticationBloc, AuthenticationState>(
              listenWhen: (p, c) => p.driveExportStatus != c.driveExportStatus,
              listener: (context, state) {
                // ... (Logica Invariata)
              },
            ),
            // Listener per l'AUTOSAVE su RTDB
            BlocListener<FlowchartBloc, FlowchartState>(
              listenWhen: (previous, current) {
                if (previous is FlowchartLoaded && current is FlowchartLoaded) {
                  return previous.flowchart != current.flowchart && !current.isDebugMode;
                }
                return previous is! FlowchartLoaded && current is FlowchartLoaded;
              },
              listener: (context, state) {
                if (state is FlowchartLoaded && _currentFileId != null && !widget.isReadOnly) {
                  final jsonContent = state.toJson();
                  if (jsonContent == _lastRtdbContent) return;

                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    if (mounted) {
                      _lastRtdbContent = jsonContent;
                      context.read<ProjectBloc>().projectRepository.updateLiveFileContent(
                        widget.selectedProject.projectId,
                        _currentFileId!,
                        jsonContent,
                      );
                    }
                  });
                }
              },
            ),
            // FIX: Listener per FileSystemBloc UNIFICATO e CORRETTO
            BlocListener<FileSystemBloc, FileSystemState>(
              listener: (context, state) async {
                if (state is FileSystemError) {
                  BannerService.showError(context, state.message);
                  return;
                }

                if (state is FileSystemLoaded) {
                  // Gestisce il cambio di file attivo e il caricamento iniziale
                  if (_currentFileId != state.activeFileId) {
                    _currentFileId = state.activeFileId;
                    await _rtdbSubscription?.cancel();

                    if (state.activeFileId == null && state.files.isNotEmpty) {
                      final mainFile = state.files.firstWhere((f) => f.name == 'main', orElse: () => state.files.first);
                      context.read<FileSystemBloc>().add(OpenFile(
                        projectId: widget.selectedProject.projectId,
                        fileId: mainFile.fileId,
                      ));
                      return;
                    }

                    if (state.activeFileId != null) {
                      final activeFile = state.files.firstWhere((f) => f.fileId == state.activeFileId);
                      if (widget.isReadOnly) {
                        context.read<FlowchartBloc>().add(LoadFlowchart(
                          jsonContent: activeFile.content,
                          fileName: activeFile.name,
                        ));
                      } else {
                        _rtdbSubscription = context.read<ProjectBloc>().projectRepository.liveFileContent(widget.selectedProject.projectId, activeFile.fileId).listen((liveContent) {
                          if (!mounted) return;
                          final flowchartBloc = context.read<FlowchartBloc>();
                          final currentState = flowchartBloc.state;
                          final contentToLoad = liveContent ?? activeFile.content;
                          if (currentState is FlowchartLoaded && currentState.toJson() == contentToLoad) return;
                          _lastRtdbContent = contentToLoad;
                          flowchartBloc.add(LoadFlowchart(
                            jsonContent: contentToLoad,
                            fileName: activeFile.name,
                          ));
                        });
                      }
                    }
                  }
                }
              },
            ),
          ],
          child: BlocBuilder<FlowchartBloc, FlowchartState>(
            builder: (ctx, fcState) {
              if (fcState is FlowchartLoaded && fcState.isDebugMode) {
                return ProgressRing();

                  //DebugModeView(
                  //workareaKey: _workareaKey,
                 // showGrid: _showGrid,
                 // onToggleGrid: _toggleGrid,
                //);
              }
              return AnimatedBuilder(
                animation: _slideInController,
                builder: (innerContext, child) {
                  return _WorkspaceLayout(
                    sidebarSlideAnimation: _sidebarSlideAnimation,
                    topbarSlideAnimation: _topbarSlideAnimation,
                    workareaSlideAnimation: _workareaSlideAnimation,
                    workareaScaleAnimation: _workareaScaleAnimation,
                    fadeAnimation: _fadeAnimation,
                    selectedProject: widget.selectedProject,
                    workareaKey: _workareaKey,
                    onEdit: _onEdit,
                    onExport: () => _handleExport(innerContext),
                    showGrid: _showGrid,
                    toggleGrid: _toggleGrid,
                    onStartDebug: () => _handleStartDebug(innerContext),
                    onAddVariable: (scope) => _handleAddVariable(innerContext, scope),
                    isReadOnly: widget.isReadOnly,
                    onLeave: widget.onLeave,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}


class _WorkspaceLayout extends StatelessWidget {
  final Animation<Offset> sidebarSlideAnimation;
  final Animation<Offset> topbarSlideAnimation;
  final Animation<Offset> workareaSlideAnimation;
  final Animation<double> workareaScaleAnimation;
  final Animation<double> fadeAnimation;
  final MyProject selectedProject;
  final GlobalKey workareaKey;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final bool showGrid;
  final VoidCallback toggleGrid;
  final VoidCallback onStartDebug;
  final void Function(VariableScope) onAddVariable; // NUOVO
  final bool isReadOnly;
  final VoidCallback? onLeave;

  const _WorkspaceLayout({
    required this.sidebarSlideAnimation,
    required this.topbarSlideAnimation,
    required this.workareaSlideAnimation,
    required this.workareaScaleAnimation,
    required this.fadeAnimation,
    required this.selectedProject,
    required this.workareaKey,
    required this.onEdit,
    required this.onExport,
    required this.showGrid,
    required this.toggleGrid,
    required this.onStartDebug,
    required this.onAddVariable,
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
            padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
            child: Column(
              children: [
                SlideTransition(
                  position: topbarSlideAnimation,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: TopBar(
                      selectedProject: selectedProject,
                      onEdit: onEdit,
                      onExport: onExport,
                      onStartDebug: onStartDebug,
                      isReadOnly: isReadOnly,
                      onLeave: onLeave,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
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
                          onAddInputVariable: () => onAddVariable(VariableScope.input),
                          onAddOutputVariable: () => onAddVariable(VariableScope.output),
                          onAddLocalVariable: () => onAddVariable(VariableScope.local),
                          allowDragInReadOnly: true,
                          isReadOnly: isReadOnly,
                        ),
                      ),
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

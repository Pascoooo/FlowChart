import 'dart:async';
import 'dart:convert';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/topbar.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
import 'package:flutter/services.dart';

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
  bool _showGrid = true;

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
    // Logic unchanged
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
    // Logic unchanged
    _debounce?.cancel();
    _rtdbSubscription?.cancel();
    _slideInController.dispose();
    super.dispose();
  }

  String _getCurrentFileName(FileSystemLoaded state) {
    // Logic unchanged
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
    // Logic unchanged
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
    // Logic unchanged
    final fileState = innerContext.read<FileSystemBloc>().state;
    if (fileState is FileSystemLoaded && fileState.activeFileId != null) {
      final fileName = _getCurrentFileName(fileState);
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes == null) {
        if (mounted) {
          BannerService.showError(
              context, "Errore durante la creazione dell'immagine.");
        }
        return;
      }
      final settingsProvider = innerContext.read<SettingsProvider>();
      final authState = innerContext.read<AuthenticationBloc>().state;
      final exportPreference = settingsProvider.exportPreference;

      switch (exportPreference) {
        case ExportPreference.local:
          await ExportService.downloadFileWithDialog(
              context: innerContext, bytes: pngBytes, fileName: fileName);
          break;
        case ExportPreference.drive:
          if (authState.user.driveConnected) {
            innerContext.read<AuthenticationBloc>().add(
                ExportFlowchartToDriveRequested(
                    fileName: '$fileName.png', fileBytes: pngBytes));
          } else {
            await AppDialogs.showExportLocationDialog(
                context: innerContext, pngBytes: pngBytes, fileName: fileName);
          }
          break;
        case ExportPreference.alwaysAsk:
          await AppDialogs.showExportLocationDialog(
              context: innerContext, pngBytes: pngBytes, fileName: fileName);
          break;
      }
    } else {
      if (!mounted) return;
      await AppDialogs.showInfoDialog(innerContext,
          title: "Nessun File Selezionato",
          message: "Seleziona un file prima di esportare.");
    }
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  @override
  Widget build(BuildContext outerContext) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: MultiBlocProvider(
        providers: [
          BlocProvider<FlowchartBloc>(create: (_) => FlowchartBloc()),
          BlocProvider<FileSystemBloc>(
            key: ValueKey('filesystem-${widget.selectedProject.projectId}'),
            create: (context) => FileSystemBloc(
              projectRepository: context.read<ProjectBloc>().projectRepository,
            )..add(
                RefreshFileSystem(projectId: widget.selectedProject.projectId)),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthenticationBloc, AuthenticationState>(
              listenWhen: (p, c) => p.driveExportStatus != c.driveExportStatus,
              listener: (context, state) {
                // Logic unchanged
                if (state.driveExportStatus == DriveExportStatus.success) {
                  BannerService.showSuccess(context,
                      "Diagramma esportato con successo su Google Drive!");
                  context
                      .read<AuthenticationBloc>()
                      .add(const ClearDriveExportStatus());
                } else if (state.driveExportStatus == DriveExportStatus.failure) {
                  BannerService.showError(
                      context, state.errorMessage ?? "Esportazione fallita.");
                  context
                      .read<AuthenticationBloc>()
                      .add(const AuthenticationErrorCleared());
                  context
                      .read<AuthenticationBloc>()
                      .add(const ClearDriveExportStatus());
                }
              },
            ),
            BlocListener<FlowchartBloc, FlowchartState>(
              listenWhen: (previous, current) {
                // Logic unchanged
                if (previous is FlowchartLoaded &&
                    current is FlowchartLoaded) {
                  return previous.flowchart != current.flowchart;
                }
                return previous is! FlowchartLoaded &&
                    current is FlowchartLoaded;
              },
              listener: (context, state) {
                // Logic unchanged
                if (state is FlowchartLoaded && _currentFileId != null) {
                  final jsonContent = state.toJson();
                  if (jsonContent == _lastRtdbContent) return;

                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    if (mounted) {
                      _lastRtdbContent = jsonContent;
                      context
                          .read<ProjectBloc>()
                          .projectRepository
                          .updateLiveFileContent(
                        widget.selectedProject.projectId,
                        _currentFileId!,
                        jsonContent,
                      );
                    }
                  });
                }
              },
            ),
// Ecco il BlocListener aggiornato.
            BlocListener<FileSystemBloc, FileSystemState>(
              // La condizione 'listenWhen' è corretta, reagiamo solo a questo stato specifico.
              listenWhen: (previous, current) => current is ShowExecutionJsonDialog,
              listener: (context, state) {
                if (state is ShowExecutionJsonDialog) {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (_) => ContentDialog(
                      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
                      title: Text('JSON esecuzione: \n${state.fileName}'),
                      content: SizedBox(
                        width: double.infinity,
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              state.formattedJson,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        Button(
                          child: const Text('Chiudi'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            // Listener per la gestione dei file
            BlocListener<FileSystemBloc, FileSystemState>(
              listenWhen: (previous, current) => current is! ShowExecutionJsonDialog,
              listener: (context, state) async {
                if (state is FileSystemLoaded) {
                  _currentFileId = state.activeFileId;
                  await _rtdbSubscription?.cancel();

                  if (state.activeFileId == null && state.files.isNotEmpty) {
                    final mainFile = state.files.firstWhere(
                            (f) => f.name == 'main',
                        orElse: () => state.files.first);
                    context.read<FileSystemBloc>().add(OpenFile(
                      projectId: widget.selectedProject.projectId,
                      fileId: mainFile.fileId,
                      fileName: mainFile.name,
                    ));
                    return;
                  }

                  if (state.activeFileId != null) {
                    final activeFile = state.files
                        .firstWhere((f) => f.fileId == state.activeFileId);
                    _rtdbSubscription = context
                        .read<ProjectBloc>()
                        .projectRepository
                        .liveFileContent(widget.selectedProject.projectId,
                        activeFile.fileId)
                        .listen((liveContent) {
                      if (!mounted) return;

                      final flowchartBloc = context.read<FlowchartBloc>();
                      final currentState = flowchartBloc.state;
                      final contentToLoad = liveContent ?? activeFile.content;

                      if (currentState is FlowchartLoaded &&
                          currentState.toJson() == contentToLoad) {
                        return;
                      }

                      _lastRtdbContent = contentToLoad;

                      flowchartBloc.add(LoadFlowchart(
                        jsonContent: contentToLoad,
                        fileName: activeFile.name,
                      ));
                    });
                  }
                } else if (state is FileSystemError) {
                  BannerService.showError(context, state.message);
                }
              },
            ),
            BlocListener<FlowchartBloc, FlowchartState>(
              listenWhen: (prev, curr) {
                if (prev is FlowchartLoaded && curr is FlowchartLoaded) {
                  final entered = !prev.isDebugMode && curr.isDebugMode;
                  final moved = curr.isDebugMode && prev.selectedNodeId != curr.selectedNodeId;
                  return entered || moved;
                }
                return false;
              },
              listener: (context, state) async {
                if (state is FlowchartLoaded && state.isDebugMode) {
                  final nodeId = state.selectedNodeId;
                  if (nodeId == null) return;
                  final node = state.getNodeById(nodeId);
                  if (node == null) return;
                  //await AppDialogs.showNodeDetailsDialog(context: context, node: node);
                }
              },
            ),
          ],
          child: BlocBuilder<FlowchartBloc, FlowchartState>(
            builder: (ctx, fcState) {
              if (fcState is FlowchartLoaded && fcState.isDebugMode) {
                return _DebugModeView(
                  workareaKey: _workareaKey,
                  showGrid: _showGrid,
                  onToggleGrid: _toggleGrid,
                );
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
            padding:
            const EdgeInsets.only(right: 16.0, bottom: 16.0),
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

class _DebugModeView extends StatefulWidget {
  final GlobalKey workareaKey;
  final bool showGrid;
  final VoidCallback onToggleGrid;
  const _DebugModeView({required this.workareaKey, required this.showGrid, required this.onToggleGrid});

  @override
  State<_DebugModeView> createState() => _DebugModeViewState();
}

class _DebugModeViewState extends State<_DebugModeView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          // Solo WorkArea, in sola lettura
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: WorkArea(
                repaintKey: widget.workareaKey,
                showGrid: widget.showGrid,
                onToggleGrid: widget.onToggleGrid,
                isReadOnly: true,
              ),
            ),
          ),
          // Pannello dettagli non modale
          Positioned(
            left: 24,
            top: 24,
            bottom: 24,
            child: SizedBox(
              width: 360,
              child: _DebugDetailsPanel(),
            ),
          ),
          // Controlli laterali: su, giù, uscita
          Positioned(
            right: 24,
            top: 24,
            bottom: 24,
            child: BlocBuilder<FlowchartBloc, FlowchartState>(
              builder: (context, state) {
                bool canPrev = false;
                bool canNext = false;
                if (state is FlowchartLoaded && state.isDebugMode) {
                  canPrev = state.debugIndex > 0;
                  canNext = state.debugIndex < (state.debugPath.length - 1);
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                      message: 'Esci dalla modalità debug',
                      child: FilledButton(
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(theme.accentColor),
                        ),
                        onPressed: () => context.read<FlowchartBloc>().add(const DebugExit()),
                        child: const Icon(FluentIcons.cancel, size: 18),
                      ),
                    ),
                    Column(
                      children: [
                        Tooltip(
                          message: 'Passo precedente',
                          child: FilledButton(
                            onPressed: canPrev ? () => context.read<FlowchartBloc>().add(const DebugPrevNode()) : null,
                            child: const Icon(FluentIcons.up, size: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Tooltip(
                          message: 'Passo successivo',
                          child: FilledButton(
                            onPressed: canNext ? () => context.read<FlowchartBloc>().add(const DebugNextNode()) : null,
                            child: const Icon(FluentIcons.down, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Indicatore di posizione
          Positioned(
            right: 24,
            bottom: 24,
            child: BlocBuilder<FlowchartBloc, FlowchartState>(
              builder: (context, state) {
                if (state is FlowchartLoaded && state.isDebugMode) {
                  return InfoLabel(
                    label: 'Posizione',
                    child: Text('${state.debugIndex + 1} / ${state.debugPath.length}'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugDetailsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is! FlowchartLoaded || !state.isDebugMode) {
          return const SizedBox.shrink();
        }
        final nodeId = state.selectedNodeId;
        if (nodeId == null) return const SizedBox.shrink();
        final node = state.getNodeById(nodeId);
        if (node == null) return const SizedBox.shrink();

        Widget buildRow(String label, String value, {bool code = false}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(label, style: theme.typography.caption),
                ),
                Expanded(
                  child: SelectableText(
                    value.isNotEmpty ? value : '–',
                    style: TextStyle(
                      fontFamily: code ? 'monospace' : null,
                      fontSize: 13,
                      color: theme.typography.body?.color,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        List<Widget> buildSpecific(FlowNode n) {
          switch (n.kind) {
            case FlowNodeKind.input:
              final input = n as InputNode;
              return [
                if (input.declarations.isEmpty)
                  Text('Nessuna variabile dichiarata', style: theme.typography.caption)
                else ...input.declarations.map((v) => buildRow('Var', '${v.dataType} ${v.name}${v.defaultValue != null ? ' = ${v.defaultValue}' : ''}', code: true)),
              ];
            case FlowNodeKind.output:
              final out = n as OutputNode;
              return [
                buildRow('Template', out.template, code: true),
                buildRow('Variabili', out.variables.join(', '), code: true),
              ];
            case FlowNodeKind.process:
              final p = n as ProcessNode;
              return [
                buildRow('Call', p.flowchartToCall, code: true),
                buildRow('Args', p.arguments.join(', '), code: true),
                buildRow('Result', p.resultTarget ?? 'Nessuno', code: true),
              ];
            case FlowNodeKind.decision:
              final d = n as DecisionNode;
              return [
                buildRow('Condizione', d.condition, code: true),
              ];
            default:
              return [buildRow('Testo', n.text)];
          }
        }

        final title = switch (node.kind) {
          FlowNodeKind.input => 'Nodo Input',
          FlowNodeKind.output => 'Nodo Output',
          FlowNodeKind.process => 'Nodo Processo',
          FlowNodeKind.decision => 'Nodo Condizione',
          FlowNodeKind.start => 'Nodo Inizio',
          FlowNodeKind.end => 'Nodo Fine',
        };

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.title),
              const SizedBox(height: 12),
              Container(height: 1, color: theme.resources.dividerStrokeColorDefault),
              const SizedBox(height: 12),
              ...buildSpecific(node),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () {
                      final map = _serializeNode(node);
                      Clipboard.setData(ClipboardData(text: jsonEncode(map)));
                    },
                    child: const Text('Copia JSON'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _serializeNode(FlowNode node) {
    final map = <String, dynamic>{
      'id': node.id,
      'kind': node.kind.name,
      'text': node.text,
    };
    if (node is InputNode) {
      map['declarations'] = [
        for (final d in node.declarations)
          {
            'name': d.name,
            'dataType': d.dataType,
            if (d.defaultValue != null) 'defaultValue': d.defaultValue,
          }
      ];
    } else if (node is OutputNode) {
      map['template'] = node.template;
      map['variables'] = node.variables;
    } else if (node is ProcessNode) {
      map['flowchartToCall'] = node.flowchartToCall;
      map['arguments'] = node.arguments;
      map['resultTarget'] = node.resultTarget;
    } else if (node is DecisionNode) {
      map['condition'] = node.condition;
    }
    return map;
  }
}

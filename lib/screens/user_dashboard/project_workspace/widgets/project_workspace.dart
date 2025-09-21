import 'dart:async';
import 'dart:convert';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/topbar.dart';
import 'package:flutter/material.dart';
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
import '../../../../config/services/dialog_service.dart';
import '../../../../config/services/export_service.dart';
import '../../../settings/widgets/settings_provider.dart';
import '../views/workarea.dart';

class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;
  const ProjectWorkspace({super.key, required this.selectedProject});

  @override
  State<ProjectWorkspace> createState() => _ProjectWorkspaceState();
}

class _ProjectWorkspaceState extends State<ProjectWorkspace> with TickerProviderStateMixin {
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
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _sidebarSlideAnimation = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideInController, curve: Curves.easeOutCubic));
    _topbarSlideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideInController, curve: Curves.easeOutCubic));
    _workareaSlideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideInController, curve: Curves.easeOutCubic));
    _workareaScaleAnimation = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _slideInController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _slideInController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)));
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
    // Cattura screenshot corrente della workarea prima di aprire l'editor di disegno
    try {
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes != null) {
        final b64 = base64Encode(pngBytes);
        html.window.localStorage['editor_last_screenshot'] = b64;
      }
    } catch (_) {
      // Silenzioso: se fallisce apriamo comunque l'editor con sfondo vuoto
    }
    final String path = Uri.base.toString().split('#')[0];
    final Uri url = Uri.parse('$path#/drawing-editor');
    html.WindowBase popup = html.window.open(url.toString(), 'editor', 'width=1200,height=800');
    if (popup.closed ?? true) {
      BannerService.showError(context, 'Popup bloccati. Abilita i popup per continuare.');
    }
  }

  Future<void> _handleExport(BuildContext innerContext) async {
    final fileState = innerContext.read<FileSystemBloc>().state;
    if (fileState is FileSystemLoaded && fileState.activeFileId != null) {
      final fileName = _getCurrentFileName(fileState);
      final pngBytes = await ExportService.generatePngBytes(key: _workareaKey);
      if (pngBytes == null) {
        if (mounted) BannerService.showError(context, "Errore fatale durante la creazione dell'immagine.");
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
            await DialogService.showExportLocationDialog(context: innerContext, pngBytes: pngBytes, fileName: fileName);
          }
          break;
        case ExportPreference.alwaysAsk:
          await DialogService.showExportLocationDialog(context: innerContext, pngBytes: pngBytes, fileName: fileName);
          break;
      }
    } else {
      if (!mounted) return;
      await DialogService.showInfoDialog(innerContext, title: "Nessun File Selezionato", message: "Per favore, seleziona un file prima di esportare.", icon: Icons.warning_amber_rounded, iconColor: Theme.of(innerContext).colorScheme.error, closeText: "Capito");
    }
  }

  void _toggleGrid() {
    setState(() => _showGrid = !_showGrid);
  }

  @override
  Widget build(BuildContext outerContext) {
    return KeyboardShortcuts(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<FlowchartBloc>(create: (_) => FlowchartBloc()),
          BlocProvider<FileSystemBloc>(
            key: ValueKey('filesystem-${widget.selectedProject.projectId}'),
            create: (context) => FileSystemBloc(
              projectRepository: context.read<ProjectBloc>().projectRepository,
            )..add(RefreshFileSystem(projectId: widget.selectedProject.projectId)),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<AuthenticationBloc, AuthenticationState>(
              listenWhen: (p, c) => p.driveExportStatus != c.driveExportStatus,
              listener: (context, state) {
                if (state.driveExportStatus == DriveExportStatus.success) {
                  BannerService.showSuccess(context, "Diagramma esportato con successo su Google Drive!");
                  context.read<AuthenticationBloc>().add(const ClearDriveExportStatus());
                } else if (state.driveExportStatus == DriveExportStatus.failure) {
                  BannerService.showError(context, state.errorMessage ?? "Esportazione fallita.");
                  context.read<AuthenticationBloc>().add(const AuthenticationErrorCleared());
                  context.read<AuthenticationBloc>().add(const ClearDriveExportStatus());
                }
              },
            ),
            BlocListener<FlowchartBloc, FlowchartState>(
              // CORREZIONE CHIAVE: Aggiorna il DB solo se cambiano forme o connessioni
              listenWhen: (previous, current) {
                if (previous is FlowchartLoaded && current is FlowchartLoaded) {
                  return previous.shapes != current.shapes || previous.connections != current.connections;
                }
                return false; // Non salvare se lo stato non è 'Loaded' o altri casi
              },
              listener: (context, state) {
                if (state is FlowchartLoaded && _currentFileId != null) {
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
            BlocListener<FileSystemBloc, FileSystemState>(
              listener: (context, state) async {
                if (state is FileSystemLoaded) {
                  _currentFileId = state.activeFileId;
                  await _rtdbSubscription?.cancel();

                  if (state.activeFileId == null && state.files.isNotEmpty) {
                    final mainFile = state.files.firstWhere((f) => f.name == 'main', orElse: () => state.files.first);
                    context.read<FileSystemBloc>().add(OpenFile(
                      projectId: widget.selectedProject.projectId,
                      fileId: mainFile.fileId,
                      fileName: mainFile.name,
                    ));
                    return;
                  }

                  if (state.activeFileId != null) {
                    final activeFile = state.files.firstWhere((f) => f.fileId == state.activeFileId);
                    _rtdbSubscription = context
                        .read<ProjectBloc>()
                        .projectRepository
                        .liveFileContent(widget.selectedProject.projectId, activeFile.fileId)
                        .listen((liveContent) {
                      if (!mounted) return;

                      final flowchartBloc = context.read<FlowchartBloc>();
                      final currentState = flowchartBloc.state;

                      final contentToLoad = liveContent ?? activeFile.content;

                      // Previene ricaricamenti inutili
                      if (currentState is FlowchartLoaded && currentState.toJson() == contentToLoad) {
                        return;
                      }

                      _lastRtdbContent = contentToLoad;

                      // CORREZIONE CHIAVE: Preserva lo stato della UI (es. selezione)
                      final remoteState = FlowchartLoaded.fromJson(contentToLoad);
                      final currentSelection = (currentState is FlowchartLoaded) ? currentState.selectedShapeId : null;
                      final selectionStillExists = currentSelection != null && remoteState.shapes.any((s) => s.id == currentSelection);

                      // Carica i nuovi dati e ripristina la selezione se possibile
                      flowchartBloc.add(LoadFlowchart(contentToLoad));
                      if(selectionStillExists) {
                        // Un piccolo ritardo per assicurarsi che lo stato sia aggiornato prima di riapplicare la selezione
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (mounted) {
                            flowchartBloc.add(SelectShape(currentSelection));
                          }
                        });
                      }
                    });
                  }
                } else if (state is FileSystemError) {
                  BannerService.showError(context, state.message);
                }
              },
            ),
          ],
          child: AnimatedBuilder(
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
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SlideTransition(
          position: sidebarSlideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ProjectSidebar(selectedProject: selectedProject),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, right: 16.0, bottom: 16.0),
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

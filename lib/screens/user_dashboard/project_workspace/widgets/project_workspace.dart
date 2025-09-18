import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_bloc.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_event.dart';
import 'package:flowchart_thesis/blocs/flowchart_bloc/flowchart_state.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/sidebar.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_workspace/widgets/topbar.dart';
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_event.dart';
import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_event.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/services/banner_service.dart';
import '../../../../config/services/dialog_service.dart';
import '../../../../config/services/export_service.dart';
import '../../../settings/widgets/settings_provider.dart';
import '../views/workarea.dart';

/// L'area di lavoro principale dove l'utente interagisce con i diagrammi.
/// Lavora esclusivamente con i dati presenti nella sessione Realtime Database.
class ProjectWorkspace extends StatefulWidget {
  final MyProject selectedProject;
  const ProjectWorkspace({super.key, required this.selectedProject});

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
  String? _currentFileId;
  ProjectRepo? _projectRepo;

  @override
  void initState() {
    super.initState();
    _projectRepo = context.read<ProjectBloc>().projectRepository;

    _initAnimations();
    _slideInController.forward();
    html.window.onBeforeUnload.listen((event) {
      if (mounted) {
        _projectRepo?.endWorkspaceSession(widget.selectedProject.projectId);
      }
    });
  }

  /// Alla distruzione del widget, si assicura di cancellare le sottoscrizioni
  /// e di richiedere la finalizzazione della sessione come ultima rete di sicurezza.
  @override
  void dispose() {
    _debounce?.cancel();
    _rtdbSubscription?.cancel();
    _projectRepo?.endWorkspaceSession(widget.selectedProject.projectId);
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
    final String path = Uri.base.toString().split('#')[0];
    final Uri url = Uri.parse('$path#/drawing-editor');

    html.WindowBase popup =
    html.window.open(url.toString(), 'editor', 'width=1200,height=800');
    if (popup.closed!) {
      throw ('Popup bloccati');
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
          await ExportService.downloadFileWithDialog(
            context: innerContext,
            bytes: pngBytes,
            fileName: fileName,
          );
          break;

        case ExportPreference.drive:
          if (authState.user.driveConnected) {
            innerContext.read<AuthenticationBloc>().add(
              ExportFlowchartToDriveRequested(
                fileName: '$fileName.png',
                fileBytes: pngBytes,
              ),
            );
          } else {
            await DialogService.showExportLocationDialog(
              context: innerContext,
              pngBytes: pngBytes,
              fileName: fileName,
            );
          }
          break;

        case ExportPreference.alwaysAsk:
          await DialogService.showExportLocationDialog(
            context: innerContext,
            pngBytes: pngBytes,
            fileName: fileName,
          );
          break;
      }
    } else {
      if (!mounted) return;
      await DialogService.showInfoDialog(
        innerContext,
        title: "Nessun File Selezionato",
        message: "Per favore, seleziona un file prima di esportare.",
        icon: Icons.warning_amber_rounded,
        iconColor: Theme.of(innerContext).colorScheme.error,
        closeText: "Capito",
      );
    }
  }


  @override
  Widget build(BuildContext outerContext) {
    return MultiBlocListener(
      listeners: [
        /// Ascolta le modifiche nel `FlowchartBloc` e le scrive su RTDB con un debounce.

        BlocListener<FileSystemBloc, FileSystemState>(
          listener: (context, state) async {
            if (state is FileSystemLoaded) {
              await _rtdbSubscription?.cancel();
              _currentFileId = state.activeFileId;

              // Se nessun file è attivo, apri il primo della lista (o 'main' se esiste)
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

              // Se un file è attivo, mettiti in ascolto dei suoi contenuti su RTDB
              if (state.activeFileId != null) {
                _rtdbSubscription = _projectRepo
                    ?.liveFileContent(
                    widget.selectedProject.projectId, state.activeFileId!)
                    .listen((liveContent) {
                  if (!mounted) return;
                  final flowchartBloc = context.read<FlowchartBloc>();
                  final flowchartState = flowchartBloc.state;

                  // **LA LOGICA CORRETTA È QUESTA**
                  // Se il contenuto live esiste E (lo stato non è caricato OPPURE il contenuto è diverso)
                  // allora carica il nuovo contenuto.
                  if (liveContent != null) {
                    bool shouldLoad = true;
                    if (flowchartState is FlowchartLoaded) {
                      if (flowchartState.toJson() == liveContent) {
                        shouldLoad = false;
                      }
                    }
                    if (shouldLoad) {
                      // **ECCO LA CHIAMATA CHE AVEVO RIMOSSO, ORA È AL POSTO GIUSTO.**
                      flowchartBloc.add(LoadFlowchart(liveContent));
                    }
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
          /// Ricostruisce il layout completo della UI.
          return _WorkspaceLayout(
            sidebarSlideAnimation: _sidebarSlideAnimation,
            topbarSlideAnimation: _topbarSlideAnimation,
            workareaSlideAnimation: _workareaSlideAnimation,
            workareaScaleAnimation: _workareaScaleAnimation,
            fadeAnimation: _fadeAnimation,
            selectedProject: widget.selectedProject,
            workareaKey: _workareaKey,
            onEdit: () { _onEdit(); },
            onExport: () { _handleExport(innerContext); },
            showGrid: _showGrid,
            toggleGrid: () => setState(() => _showGrid = !_showGrid),
          );
        },
      ),
    );
  }

  /// Inizializza tutte le animazioni della UI.
  void _initAnimations() {
    _slideInController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
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
}

/// Widget puramente di layout per organizzare la UI del workspace.
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
            padding:
            const EdgeInsets.only(top: 16.0, right: 16.0, bottom: 16.0),
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
                      showGrid: showGrid,
                      onToggleGrid: toggleGrid,
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
                        child: _WorkspaceContent(
                            workareaKey: workareaKey, showGrid: showGrid),
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

/// Mostra l'area di lavoro o un messaggio se nessun file è selezionato.
class _WorkspaceContent extends StatelessWidget {
  final GlobalKey workareaKey;
  final bool showGrid;

  const _WorkspaceContent({required this.workareaKey, required this.showGrid});

  @override
  Widget build(BuildContext context) {
    final hasActiveFile = context.select<FileSystemBloc, bool>((bloc) =>
    bloc.state is FileSystemLoaded &&
        (bloc.state as FileSystemLoaded).activeFileId != null);

    return Stack(
      children: [
        WorkArea(repaintKey: workareaKey, showGrid: showGrid),
        if (!hasActiveFile)
          const IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Seleziona o crea un file per iniziare.'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
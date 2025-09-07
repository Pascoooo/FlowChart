import 'package:flowchart_thesis/blocs/auth_bloc/authentication_bloc.dart';
import 'package:flowchart_thesis/blocs/auth_bloc/authentication_event.dart';
import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../config/constants/theme_switch.dart';
import '../../../config/services/dialog_service.dart';

class ProjectSelector extends StatefulWidget {
  final List<MyProject> projects;
  final Function(MyProject) onProjectSelected;
  final Function(String) onCreateProject;

  const ProjectSelector({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onCreateProject,
  });

  @override
  State<ProjectSelector> createState() => _ProjectSelectorState();
}

class _ProjectSelectorState extends State<ProjectSelector>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<double>> _itemAnimations;

  late PageController _pageController;
  int _currentPage = 0;
  static const int _projectsPerPage = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initAnimations();
  }

  void _initAnimations() {
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _itemAnimations = List.generate(
      _projectsPerPage,
          (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.6,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages => (widget.projects.length / _projectsPerPage).ceil();
  bool get _canNavigateLeft => _currentPage > 0;
  bool get _canNavigateRight => _currentPage < _totalPages - 1;

  void _navigateToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contenitore per allineare l'avatar a destra del riquadro
                Container(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildProfileMenu(theme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildProjectContainer(theme),
                const SizedBox(height: 32),
                _buildCreateButton(theme),
              ],
            ),
          ),
        ),
        // Pulsante per il toggle del tema
        Positioned(
          bottom: 24,
          right: 24,
          child: _buildThemeToggleButton(theme),
        ),
      ],
    );
  }

  Widget _buildProjectContainer(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000, minHeight: 450),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            theme.colorScheme.surface.withOpacity(0.8),
          ],
        ),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildContainerHeader(theme),
          const SizedBox(height: 24),
          widget.projects.isNotEmpty
              ? _buildProjectCarousel(theme)
              : _buildEmptyState(theme),
        ],
      ),
    );
  }

  Widget _buildContainerHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          BlocBuilder<AuthenticationBloc, AuthenticationState>(
            builder: (context, state) {
              String username = "Utente";
              if (state.status == AuthenticationStatus.authenticated) {
                username = state.user.name;
              }
              return Text(
                "Ciao $username, bentornato!",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            "Seleziona un progetto recente o creane uno nuovo per iniziare.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenu(ThemeData theme) {
    final user = context.watch<AuthenticationBloc>().state.user;

    return PopupMenuButton<String>(
      tooltip: "Opzioni profilo",
      offset: const Offset(0, 50),
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'logout') {
          final confirm = await DialogService.showConfirmationDialog(context,
              title: "Logout",
              message: "Sei sicuro di voler uscire?",
              confirmText: "Esci",
              cancelText: "Annulla");
          if (confirm == true) {
            context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
          }
        } else if (value == 'settings') {
          AppRouter.goToSettings(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              const Text("Impostazioni"),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Text("Logout", style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: (user.photoURL.isNotEmpty)
            ? NetworkImage(user.photoURL)
            : null,
        child: (user.photoURL.isEmpty)
            ? const Icon(Icons.person_outline, size: 24)
            : null,
      ),
    );
  }

  Widget _buildProjectCarousel(ThemeData theme) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: _totalPages,
            itemBuilder: (context, pageIndex) {
              return _buildProjectPage(theme, pageIndex);
            },
          ),
          if (_canNavigateLeft)
            Positioned(
              left: 16, top: 0, bottom: 0,
              child: Center(child: _buildNavigationButton(theme, Icons.arrow_back_ios, () => _navigateToPage(_currentPage - 1))),
            ),
          if (_canNavigateRight)
            Positioned(
              right: 16, top: 0, bottom: 0,
              child: Center(child: _buildNavigationButton(theme, Icons.arrow_forward_ios, () => _navigateToPage(_currentPage + 1))),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton(ThemeData theme, IconData icon, VoidCallback onTap) {
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildProjectPage(ThemeData theme, int pageIndex) {
    final startIndex = pageIndex * _projectsPerPage;
    final endIndex = (startIndex + _projectsPerPage).clamp(0, widget.projects.length);
    final pageProjects = widget.projects.sublist(startIndex, endIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pageProjects.asMap().entries.map((entry) {
          final index = entry.key;
          final project = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AnimatedBuilder(
              animation: _itemAnimations[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - _itemAnimations[index].value)),
                  child: Opacity(
                    opacity: _itemAnimations[index].value,
                    child: _buildProjectCard(theme, project),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProjectCard(ThemeData theme, MyProject project) {
    return SizedBox(
      width: 200,
      height: 180, // Dimensione fissa
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
              theme.colorScheme.surface.withOpacity(0.9),
            ],
          ),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onProjectSelected(project),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            theme.colorScheme.primary.withOpacity(0.2),
                            theme.colorScheme.primary.withOpacity(0.1),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(FontAwesomeIcons.folder, size: 20, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        project.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: _buildCardPopupMenu(theme, project),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPopupMenu(ThemeData theme, MyProject project) {
    return PopupMenuButton<String>(
      tooltip: "Opzioni",
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'rename') {
          final newName = await DialogService.showInputDialog(context,
              title: "Rinomina progetto", message: "Inserisci un nuovo nome per il progetto",
              hintText: project.name, confirmText: "Rinomina", cancelText: "Annulla");
          if (newName != null && newName.isNotEmpty) {
            context.read<ProjectBloc>().add(RenameProject(projectId: project.projectId, newName: newName));
          }
        } else if (value == 'delete') {
          final confirm = await DialogService.showConfirmationDialog(context,
              title: "Elimina progetto", message: "Sei sicuro di voler eliminare '${project.name}'?",
              confirmText: "Elimina", cancelText: "Annulla");
          if (confirm == true) {
            context.read<ProjectBloc>().add(DeleteProject(projectId: project.projectId));
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [const Icon(Icons.edit, size: 16), const SizedBox(width: 8), const Text("Rinomina")],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text("Elimina", style: TextStyle(color: theme.colorScheme.error))
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.more_vert, size: 16, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(FontAwesomeIcons.folderOpen, size: 24, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
          const SizedBox(height: 12),
          Text("Nessun progetto trovato", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("Inizia creando il tuo primo progetto", textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCreateButton(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCreateProjectDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(FontAwesomeIcons.plus, size: 16, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(
                  widget.projects.isEmpty ? "Crea il tuo primo progetto" : "Nuovo Progetto",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
                child: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                  key: ValueKey(Theme.of(context).brightness),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final String? projectName = await DialogService.showInputDialog(
      context,
      title: "Nuovo Progetto",
      message: "Dai un nome al tuo progetto per iniziare",
      hintText: "es. Il mio diagramma di flusso",
      confirmText: "Crea Progetto",
      cancelText: "Annulla",
    );

    if (projectName != null && projectName.isNotEmpty) {
      widget.onCreateProject(projectName);
    }
  }
}
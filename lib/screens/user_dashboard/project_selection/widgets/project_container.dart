/// Main container for project grid displaying all projects in a carousel.
/// Features animated entrance, header with icon, "Open with ID" button for shared projects.
/// Shows empty state with floating animation when no projects exist.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/themes.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import 'project_carousel.dart';

class ProjectContainer extends StatefulWidget {
  final List<MyProject> projects;
  final void Function(MyProject) onProjectSelected;
  final void Function(String) onProjectDeleted;
  final void Function(String, String) onProjectRenamed;

  const ProjectContainer({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onProjectDeleted,
    required this.onProjectRenamed,
  });

  @override
  State<ProjectContainer> createState() => ProjectContainerState();
}

class ProjectContainerState extends State<ProjectContainer>
    with TickerProviderStateMixin {
  late AnimationController _containerController;
  late Animation<double> _containerAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _containerController.forward();
  }

  /// Initializes container and header slide animations for entrance effect.
  void _initializeAnimations() {
    _containerController = AnimationController(
      duration: AppConstants.animationDuration,
      vsync: this,
    );

    _containerAnimation = CurvedAnimation(
      parent: _containerController,
      curve: Curves.easeOutCubic,
    );

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(_containerAnimation);
  }

  @override
  void dispose() {
    _containerController.dispose();
    super.dispose();
  }

  /// Builds animated container with header, project carousel, and "Open with ID" button.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return AnimatedBuilder(
      animation: _containerAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _containerAnimation.value),
          child: Container(
            width: AppConstants.projectContainerWidth,
            height: AppConstants.projectContainerHeight,
            decoration: _buildContainerDecoration(theme),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    _buildEnhancedHeader(theme),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 250,
                      child: _buildContent(),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildViewSharedButton(context, theme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// Renders button for opening shared projects via project ID input dialog.
  Widget _buildViewSharedButton(BuildContext context, FluentThemeData theme) {
    return Tooltip(
      message: "Apri progetto condiviso",
      // Usiamo un Button standard per un look più pulito, adatto ad un'azione secondaria.
      child: Button(
        style: ButtonStyle(
          backgroundColor:
          ButtonState.all(theme.accentColor.withOpacity(0.1)),
          foregroundColor: ButtonState.all(theme.accentColor),
          shape: ButtonState.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.borderRadiusSmall),
          )),
        ),
        // La logica onPressed è IDENTICA all'originale, come richiesto.
        onPressed: () async {
          final projectId = await AppDialogs.showInputDialog(
              context,
              title: "Apri Progetto Condiviso",
              message: "Incolla l'ID del progetto che vuoi visualizzare.",
              hintText: "ID Progetto...",
              confirmText: "Apri",
              cancelText: "Annulla",
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "L'ID del progetto non può essere vuoto.";
                }
                return null;
              },
              inputLabel: "ID Progetto");
          if (projectId != null && projectId.trim().isNotEmpty) {
            context
                .read<ProjectBloc>()
                .add(LoadStaticWorkspace(projectId: projectId.trim()));
          }
        },
        // Applichiamo un padding generoso per risolvere il problema delle dimensioni.
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            children: [
              Icon(FontAwesomeIcons.link, size: 16),
              SizedBox(width: 8),
              Text("Apri con ID"),
            ],
          ),
        ),
      ),
    );
  }

  /// Creates gradient decoration with borders and shadows for container.
  BoxDecoration _buildContainerDecoration(FluentThemeData theme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.cardColor.withOpacity(0.4),
          theme.cardColor.withOpacity(0.9),
          theme.cardColor.withOpacity(0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      border: Border.all(
        color: theme.inactiveColor.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 32,
          spreadRadius: 4,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: theme.accentColor.withOpacity(0.05),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Builds animated header with folder icon and "Your Projects" title.
  Widget _buildEnhancedHeader(FluentThemeData theme) {
    return SlideTransition(
      position: _headerSlideAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.accentColor.withOpacity(0.2),
                        theme.accentColor.lighter.withOpacity(0.1),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(AppStyles.borderRadiusSmall),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.folderOpen,
                    size: 26,
                    color: theme.accentColor,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "I tuoi progetti",
                  style: theme.typography.title
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns carousel with projects if available, otherwise shows empty state.
  Widget _buildContent() {
    return widget.projects.isNotEmpty
        ? ProjectCarousel(
      projects: widget.projects,
      onProjectSelected: widget.onProjectSelected,
      onProjectDeleted: widget.onProjectDeleted,
      onProjectRenamed: widget.onProjectRenamed,
    )
        : const EnhancedEmptyState();
  }
}

/// Empty state widget with floating icon animation shown when no projects exist.
/// Features inspirational message encouraging user to create first project.
class EnhancedEmptyState extends StatefulWidget {
  const EnhancedEmptyState({super.key});

  @override
  State<EnhancedEmptyState> createState() => _EnhancedEmptyStateState();
}

class _EnhancedEmptyStateState extends State<EnhancedEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  /// Sets up continuous floating animation for empty state icon.
  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  /// Builds empty state with floating folder icon and motivational message.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnimation.value),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.accentColor.lighter.withOpacity(0.3),
                      theme.accentColor.lightest.withOpacity(0.2),
                    ],
                  ),
                ),
                child: FaIcon(
                  FontAwesomeIcons.folderPlus,
                  size: 48,
                  color: theme.accentColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Nessun progetto trovato",
                style: theme.typography.subtitle
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(AppStyles.borderRadiusMedium),
                  color: theme.cardColor.withOpacity(0.5),
                ),
                child: Text(
                  "Inizia il tuo viaggio creativo con il primo progetto",
                  textAlign: TextAlign.center,
                  style: theme.typography.body?.copyWith(
                    color: theme.typography.body?.color?.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

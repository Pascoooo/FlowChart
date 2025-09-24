import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_selection/widgets/project_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/constants/themes.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _containerAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _containerAnimation.value),
          child: Container(
            width: AppConstants.projectContainerWidth,
            height: AppConstants.projectContainerHeight,
            decoration: _buildContainerDecoration(theme),
            child: Stack( // Use a Stack to overlay the new button
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
                // Position the new button in the top right corner
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

  /// **NUOVO PULSANTE "APRI CON ID"**
  /// **NUOVO PULSANTE "APRI CON ID"**
  Widget _buildViewSharedButton(BuildContext context, ThemeData theme) {
    return Tooltip(
      message: "Apri progetto condiviso",
      child: ElevatedButton.icon(
        icon: const FaIcon(FontAwesomeIcons.link, size: 16),
        label: const Text("Apri con ID"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          final projectId = await AppDialogs.showInputDialog(
            context,
            title: "Apri Progetto Condiviso",
            message: "Incolla l'ID del progetto che vuoi visualizzare.",
            hintText: "ID Progetto...",
            confirmText: "Apri",
          );
          if (projectId != null && projectId.trim().isNotEmpty) {
            context.read<ProjectBloc>().add(LoadStaticWorkspace(projectId: projectId.trim()));
          }
        },
      ),
    );
  }

  BoxDecoration _buildContainerDecoration(ThemeData theme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          theme.colorScheme.surface.withValues(alpha: 0.9),
          theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.1),
          blurRadius: 32,
          spreadRadius: 4,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildEnhancedHeader(ThemeData theme) {
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
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                        theme.colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppStyles.borderRadiusSmall),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.folderOpen,
                    size: 26,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "I tuoi progetti",
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

class EnhancedEmptyState extends StatefulWidget {
  const EnhancedEmptyState({super.key});

  @override
  State<EnhancedEmptyState> createState() => _EnhancedEmptyStateState();
}

class _EnhancedEmptyStateState extends State<EnhancedEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

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
  void reassemble() {
    super.reassemble();
    if (_floatingController.isAnimating) {
      _floatingController.stop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _floatingController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      theme.colorScheme.secondaryContainer.withOpacity(0.2),
                    ],
                  ),
                ),
                child: FaIcon(
                  FontAwesomeIcons.folderPlus,
                  size: 48,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Nessun progetto trovato",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppStyles.borderRadiusMedium),
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: Text(
                  "Inizia il tuo viaggio creativo con il primo progetto",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
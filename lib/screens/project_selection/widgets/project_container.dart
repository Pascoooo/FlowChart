import 'package:flowchart_thesis/screens/project_selection/widgets/project_carousel.dart';
import 'package:flowchart_thesis/screens/project_selection/widgets/welcome_header.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';

import '../../../config/constants/themes.dart';

class EnhancedProjectContainer extends StatefulWidget {
  final List<MyProject> projects;
  final void Function(MyProject) onProjectSelected;
  final void Function(String) onProjectDeleted;
  final void Function(String, String) onProjectRenamed;

  const EnhancedProjectContainer({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onProjectDeleted,
    required this.onProjectRenamed,
  });

  @override
  State<EnhancedProjectContainer> createState() => _EnhancedProjectContainerState();
}

class _EnhancedProjectContainerState extends State<EnhancedProjectContainer>
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
            child: Column(
              children: [
                _buildEnhancedHeader(theme),
                const SizedBox(height: 32),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildContainerDecoration(ThemeData theme) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          theme.colorScheme.surface.withOpacity(0.9),
          theme.colorScheme.surfaceContainerLow.withOpacity(0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withOpacity(0.1),
          blurRadius: 32,
          spreadRadius: 4,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: theme.colorScheme.primary.withOpacity(0.05),
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
                        theme.colorScheme.primary.withOpacity(0.2),
                        theme.colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppStyles.borderRadiusSmall),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.folderOpen,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "I tuoi progetti",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              ),
              child: Text(
                "${widget.projects.length} ${widget.projects.length == 1 ? 'progetto' : 'progetti'} disponibili",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

// widgets/enhanced_empty_state.dart
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
                  color: theme.colorScheme.primary.withOpacity(0.7),
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
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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

class ErrorHandler {
  static void handleError(BuildContext context, String message, [String? title]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static Future<void> handleAsyncError(
      Future<void> Function() operation,
      BuildContext context, [
        String? errorMessage,
      ]) async {
    try {
      await operation();
    } catch (e) {
      if (context.mounted) {
        handleError(context, errorMessage ?? 'Si è verificato un errore');
      }
    }
  }
}

// utils/validation_utils.dart
class ValidationUtils {
  static String? validateProjectName(String value, List<MyProject> existingProjects, [String? currentProjectId]) {
    if (value.trim().isEmpty) {
      return 'Il nome non può essere vuoto';
    }

    if (value.trim().length > AppConstants.maxProjectNameLength) {
      return 'Nome troppo lungo (max ${AppConstants.maxProjectNameLength} caratteri)';
    }

    final normalizedValue = value.trim().toLowerCase();
    final exists = existingProjects.any((p) =>
    p.projectId != currentProjectId &&
        p.name.toLowerCase() == normalizedValue
    );

    if (exists) {
      return 'Esiste già un progetto con questo nome';
    }

    // Check for invalid characters
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(value)) {
      return 'Il nome contiene caratteri non validi';
    }

    return null;
  }
}

class NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavigationButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}
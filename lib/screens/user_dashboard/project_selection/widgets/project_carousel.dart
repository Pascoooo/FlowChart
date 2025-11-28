/// Responsive paginated carousel for displaying project cards.
/// Automatically adjusts projects per page based on viewport width (1-3 cards).
/// Features staggered entrance animations and smooth page transitions.
import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';
import 'project_card.dart';

class ProjectCarousel extends StatefulWidget {
  final List<MyProject> projects;
  final Function(MyProject) onProjectSelected;
  final Function(String) onProjectDeleted;
  final Function(String, String) onProjectRenamed;

  const ProjectCarousel({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    required this.onProjectDeleted,
    required this.onProjectRenamed,
  });

  @override
  State<ProjectCarousel> createState() => _ProjectCarouselState();
}

class _ProjectCarouselState extends State<ProjectCarousel>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _staggerController;
  int _currentPage = 0;
  int _projectsPerPage = 3;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _staggerController.forward();
  }

  @override
  void didUpdateWidget(covariant ProjectCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projects.length != widget.projects.length) {
      _staggerController.forward(from: 0);
      final total = _totalPages;
      if (_currentPage >= total && total > 0) {
        setState(() => _currentPage = total - 1);
        _pageController.jumpToPage(_currentPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  int get _totalPages => widget.projects.isEmpty
      ? 0
      : (widget.projects.length / _projectsPerPage).ceil();

  /// Animates transition to specified page with smooth easing.
  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Creates staggered animation for card at given index with delayed start.
  Animation<double> _animationFor(int index) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  /// Builds responsive carousel with navigation buttons and adaptive layout.
  /// Adjusts projects per page: 3 (≥880px), 2 (651-879px), 1 (≤650px).
  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 880) {
          _projectsPerPage = 3;
        } else if (constraints.maxWidth > 650) {
          _projectsPerPage = 2;
        } else {
          _projectsPerPage = 1;
        }

        return SizedBox(
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _totalPages,
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * _projectsPerPage;
                  final endIndex =
                  min(startIndex + _projectsPerPage, widget.projects.length);
                  final pageProjects =
                  widget.projects.sublist(startIndex, endIndex);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: pageProjects.asMap().entries.map((entry) {
                        final index = entry.key;
                        final project = entry.value;
                        final anim = _animationFor(index);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: AnimatedBuilder(
                            animation: anim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, 20 * (1 - anim.value)),
                              child: Opacity(opacity: anim.value, child: child),
                            ),
                            child: ProjectCard(
                              project: project,
                              projects: widget.projects,
                              onTap: () => widget.onProjectSelected(project),
                              onDeleted: () =>
                                  widget.onProjectDeleted(project.projectId),
                              onRenamed: (newName) => widget
                                  .onProjectRenamed(project.projectId, newName),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              if (_currentPage > 0)
                Positioned(
                  left: 16,
                  child: _NavigationButton(
                    icon: FontAwesomeIcons.chevronLeft,
                    onTap: () => _navigateToPage(_currentPage - 1),
                  ),
                ),
              if (_currentPage < _totalPages - 1)
                Positioned(
                  right: 16,
                  child: _NavigationButton(
                    icon: FontAwesomeIcons.chevronRight,
                    onTap: () => _navigateToPage(_currentPage + 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Circular navigation button for carousel with hover and press states.
class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavigationButton({required this.icon, required this.onTap});

  /// Builds circular button with accent color on hover and press.
  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onTap,
      style: ButtonStyle(
        shape: ButtonState.all(const CircleBorder()),
        padding: ButtonState.all(const EdgeInsets.all(12)),
        backgroundColor: ButtonState.resolveWith((states) {
          final theme = FluentTheme.of(context);
          if (states.isPressing) {
            return theme.accentColor.withOpacity(0.2);
          }
          if (states.isHovering) {
            return theme.accentColor.withOpacity(0.1);
          }
          return Colors.transparent;
        }),
      ),
      child: Icon(icon, size: 20),
    );
  }
}

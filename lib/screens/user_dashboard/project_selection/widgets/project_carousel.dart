import 'dart:math';
import 'package:flowchart_thesis/screens/user_dashboard/project_selection/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../config/widgets/buttons.dart';

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

class _ProjectCarouselState extends State<ProjectCarousel> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _staggerController;
  int _currentPage = 0;
  static const int _projectsPerPage = 3;

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
      // Riavvia lo stagger quando cambia il numero di progetti
      _staggerController.forward(from: 0);
      // Se la pagina corrente ora è fuori range, la riporto all'ultima valida
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

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Animation<double> _animationFor(int index) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Nessun progetto. Crea il tuo primo progetto!',
            textAlign: TextAlign.center,
          ),
        ),
      );
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
              final endIndex = min(startIndex + _projectsPerPage, widget.projects.length);
              final pageProjects = widget.projects.sublist(startIndex, endIndex);

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
                          onDeleted: () => widget.onProjectDeleted(project.projectId),
                          onRenamed: (newName) => widget.onProjectRenamed(project.projectId, newName),
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
              child: NavigationButton(
                icon: Icons.arrow_back_ios,
                onTap: () => _navigateToPage(_currentPage - 1),
              ),
            ),
          if (_currentPage < _totalPages - 1)
            Positioned(
              right: 16,
              child: NavigationButton(
                icon: Icons.arrow_forward_ios,
                onTap: () => _navigateToPage(_currentPage + 1),
              ),
            ),
        ],
      ),
    );
  }
}
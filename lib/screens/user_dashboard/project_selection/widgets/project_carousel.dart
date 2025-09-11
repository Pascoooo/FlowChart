import 'dart:math';
import 'package:flowchart_thesis/screens/user_dashboard/project_selection/widgets/project_card.dart';
import 'package:flowchart_thesis/screens/user_dashboard/project_selection/widgets/project_container.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';

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
  late final List<Animation<double>> _itemAnimations;

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

    _itemAnimations = List.generate(
      min(_projectsPerPage, widget.projects.length),
          (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval((index * 0.1), (index * 0.1) + 0.6, curve: Curves.easeOutCubic),
        ),
      ),
    );

    _staggerController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  int get _totalPages => (widget.projects.length / _projectsPerPage).ceil();

  void _navigateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, 20 * (1 - _itemAnimations[index].value)),
                          child: Opacity(opacity: _itemAnimations[index].value, child: child),
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
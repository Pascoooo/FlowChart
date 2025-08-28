// lib/screens/user_dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import '../animations/background_animation.dart';
import '../widgets/sidebar.dart';
import 'dashboard_content.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withOpacity(0.98),
              theme.colorScheme.surfaceVariant.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            const AnimatedBackground(),
            Row(
              children: [
                const ProjectSidebar(),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _contentAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(30 * (1 - _contentAnimation.value), 0),
                        child: Opacity(
                          opacity: _contentAnimation.value,
                          child: const DashboardContent(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

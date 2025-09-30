import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ModernLoadingIndicator extends StatefulWidget {
  const ModernLoadingIndicator({super.key});

  @override
  State<ModernLoadingIndicator> createState() => _ModernLoadingIndicatorState();
}

class _ModernLoadingIndicatorState extends State<ModernLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.diagramProject,
              size: 48,
              color: theme.accentColor,
            ),
            const SizedBox(height: 32),
            SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Text(
                    "Caricamento Progetti",
                    style: theme.typography.title
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Quasi pronto...",
                    style: theme.typography.body?.copyWith(
                      color: theme.typography.body?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: ProgressBar(
                      backgroundColor: theme.inactiveColor.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

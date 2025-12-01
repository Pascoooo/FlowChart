/// Modern loading indicator with fade-in animation and progress bar.
/// Displays "Loading Projects" message with icon and animated entrance.
import 'package:fluent_ui/fluent_ui.dart';

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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.brightness == Brightness.light ? theme.cardColor : null,
                gradient: theme.brightness == Brightness.dark
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.accentColor.dark,
                          theme.accentColor,
                          theme.accentColor.light,
                        ],
                      )
                    : null,
                border: theme.brightness == Brightness.light
                    ? Border.all(
                        color: theme.accentColor,
                        width: 2.5,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
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

/// Animated welcome header displaying personalized greeting with user's name.
/// Features fade-in, slide, and scale animations for hero icon and text.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_state.dart';
import '../../../../config/constants/app_constants.dart';
import '../../../../config/constants/themes.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => WelcomeHeaderState();
}

class WelcomeHeaderState extends State<WelcomeHeader>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _decorationController;
  late Animation<double> _heroAnimation;
  late Animation<double> _decorationAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  /// Sets up hero and decoration animation controllers with fade, slide, and scale effects.
  void _initializeAnimations() {
    _heroController = AnimationController(
      duration: AppConstants.animationDuration,
      vsync: this,
    );

    _decorationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );

    _decorationAnimation = CurvedAnimation(
      parent: _decorationController,
      curve: Curves.elasticOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_heroAnimation);
  }

  /// Triggers animation sequence with staggered timing for smooth entry effect.
  void _startAnimations() {
    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _decorationController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _decorationController.dispose();
    super.dispose();
  }

  /// Builds animated header with hero icon, personalized welcome text, and subtitle.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _heroAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeroIcon(theme),
                const SizedBox(height: 24),
                _buildWelcomeText(theme),
                const SizedBox(height: 12),
                _buildSubtitle(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Renders animated hero icon with gradient background and shadow effects.
  Widget _buildHeroIcon(FluentThemeData theme) {
    return AnimatedBuilder(
      animation: _decorationAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _decorationAnimation.value),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.accentColor,
                  theme.accentColor.lighter,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const FaIcon(
              FontAwesomeIcons.diagramProject,
              size: 32,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  /// Displays personalized welcome message with user's name fetched from AuthenticationBloc.
  Widget _buildWelcomeText(FluentThemeData theme) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        final username = state.status == AuthenticationStatus.authenticated
            ? state.user.name
            : "Utente";

        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.typography.title?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.typography.body?.color,
              fontSize: (theme.typography.title?.fontSize ?? 32) + 4,
            ),
            children: [
              const TextSpan(text: "Bentornato, "),
              TextSpan(
                text: username,
                style: TextStyle(
                  color: theme.accentColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const TextSpan(text: "!"),
            ],
          ),
        );
      },
    );
  }

  /// Renders subtitle with inspirational message in styled container.
  Widget _buildSubtitle(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusMedium),
        color: theme.cardColor.withOpacity(0.3),
      ),
      child: Text(
        "Trasforma le tue idee in diagrammi professionali",
        textAlign: TextAlign.center,
        style: theme.typography.bodyStrong?.copyWith(
          color: theme.typography.body?.color?.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

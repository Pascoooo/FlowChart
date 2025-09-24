import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_event.dart';
import '../../../../blocs/auth_bloc/authentication_state.dart';
import '../../../../config/constants/themes.dart';
import '../../../../config/router/app_router.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

  Widget _buildHeroIcon(ThemeData theme) {
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
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FaIcon(
              FontAwesomeIcons.diagramProject,
              size: 32,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeText(ThemeData theme) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        final username = state.status == AuthenticationStatus.authenticated
            ? state.user.name
            : "Utente";

        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              fontSize: (theme.textTheme.headlineLarge?.fontSize ?? 32) + 4,
            ),
            children: [
              const TextSpan(text: "Bentornato, "),
              TextSpan(
                text: username,
                style: TextStyle(
                  color: theme.colorScheme.primary,
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

  Widget _buildSubtitle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusMedium),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Text(
        "Trasforma le tue idee in diagrammi professionali",
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

}

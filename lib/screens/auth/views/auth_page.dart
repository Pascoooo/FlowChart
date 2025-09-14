import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:user_repository/user_repository.dart';
import '../../../config/constants/theme_switch.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
// MIGLIORAMENTO: Importiamo il nuovo BannerService
import '../../../config/services/banner_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/brand_panel.dart';
import '../widgets/social_buttons.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart),
    );
    _slideAnimation = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() {
    context.read<AuthenticationBloc>().add(
      const AuthenticationGoogleSignInRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 1200;

    // Usiamo un BlocListener per gestire azioni come navigazione e banner
    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        // Azione 1: Navigazione in caso di successo
        if (state.status == AuthenticationStatus.authenticated) {
          AppRouter.goToHome(context);
        }

        // MIGLIORAMENTO: Azione 2: Mostra il banner di errore con il nuovo servizio
        if (state.errorMessage != null) {
          // Mostra il banner...
          BannerService.showError(context, state.errorMessage!);
          // ...e pulisce subito lo stato dell'errore.
          context.read<AuthenticationBloc>().add(const AuthenticationErrorCleared());
        }
      },
      // Usiamo un BlocBuilder per costruire la UI in base allo stato
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          if (state.status == AuthenticationStatus.unknown) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final isGoogleLoading = state.isLoading;
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: SafeArea(
              child: isWide
                  ? _buildWideLayout(isGoogleLoading)
                  : _buildNarrowLayout(isGoogleLoading),
            ),
          );
        },
      ),
    );
  }

  // MIGLIORAMENTO: Rimosso il parametro del banner, non serve più
  Widget _buildWideLayout(bool isGoogleLoading) {
    return Row(
      children: [
        const Expanded(flex: 5, child: BrandPanel()),
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // Non mostriamo più il banner qui
              child: _buildAuthCard(isGoogleLoading),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(bool isGoogleLoading) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          // Non mostriamo più il banner qui
          child: _buildAuthCard(isGoogleLoading),
        ),
      ),
    );
  }



  Widget _buildAuthCard(bool isGoogleLoading) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(24),
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : theme.colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(
                    title: 'Benvenuto',
                    subtitle: 'Accedi a Flowchart Thesis',
                    isDark: isDark,
                    onThemeToggle: () =>
                        Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
                  ),
                  const SizedBox(height: 32),
                  SocialAuthButton(
                    text: 'Continua con Google',
                    icon: FontAwesomeIcons.google,
                    onPressed: _handleGoogleSignIn,
                    isLoading: isGoogleLoading,
                    iconColor: const Color(0xFF4285F4),
                    isPrimary: true,
                    isEnabled: !isGoogleLoading,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Sicuro e veloce',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Accedendo, accetti i nostri Termini di Servizio e la Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
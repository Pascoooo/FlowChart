import 'package:flowchart_thesis/config/router/app_router.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:user_repository/user_repository.dart';
import '../../../config/constants/theme_switch.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
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
    _slideAnimation = Tween(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
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
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 1200;

    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.status == AuthenticationStatus.authenticated) {
          AppRouter.goToHome(context);
        }
        if (state.errorMessage != null) {
          BannerService.showError(context, state.errorMessage!);
          context.read<AuthenticationBloc>().add(const AuthenticationErrorCleared());
        }
      },
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          if (state.status == AuthenticationStatus.unknown) {
            return const ScaffoldPage(
              content: Center(child: ProgressRing()),
            );
          }

          final isGoogleLoading = state.isLoading;
          return ScaffoldPage(
            content: SafeArea(
              child: isWide
                  ? _buildWideLayout(isGoogleLoading)
                  : _buildNarrowLayout(isGoogleLoading),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout(bool isGoogleLoading) {
    return Row(
      children: [
        const Expanded(flex: 5, child: BrandPanel()),
        Expanded(
          flex: 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _buildAuthCard(isGoogleLoading),
        ),
      ),
    );
  }

  Widget _buildAuthCard(bool isGoogleLoading) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
            border: Border.all(
              color: theme.inactiveColor.withOpacity(0.3),
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
                    Provider.of<ThemeProvider>(context, listen: false)
                        .toggleTheme(),
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
                    child: Divider(
                        style: DividerThemeData(
                            decoration:
                            BoxDecoration(color: theme.inactiveColor.withOpacity(0.5)))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Sicuro e veloce',
                      style: theme.typography.caption?.copyWith(
                        color: theme.typography.caption?.color?.withOpacity(0.8),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                        style: DividerThemeData(
                            decoration:
                            BoxDecoration(color: theme.inactiveColor.withOpacity(0.5)))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Accedendo, accetti i nostri Termini di Servizio e la Privacy Policy.',
                textAlign: TextAlign.center,
                style: theme.typography.caption?.copyWith(
                  color: theme.typography.caption?.color?.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
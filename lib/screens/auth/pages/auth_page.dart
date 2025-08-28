// dart
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

  Future<void> _handleGoogleSignIn() async {
    context.read<AuthenticationBloc>().add(
      const AuthenticationGoogleSignInRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 1200;

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.status == AuthenticationStatus.authenticated) {
          AppRouter.goToHome(context);
        }
      },
      builder: (context, state) {
        if (state.status == AuthenticationStatus.unknown) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final bannerMessage = state.errorMessage;
        final isGoogleLoading = state.isLoading;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: isWide
                ? _buildWideLayout(bannerMessage, isGoogleLoading)
                : _buildNarrowLayout(bannerMessage, isGoogleLoading),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(String? bannerMessage, bool isGoogleLoading) {
    return Row(
      children: [
        const Expanded(flex: 5, child: BrandPanel()),
        Expanded(
          flex: 4,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bannerMessage != null) _buildErrorBanner(bannerMessage),
                _buildAuthCard(isGoogleLoading),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(String? bannerMessage, bool isGoogleLoading) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bannerMessage != null) _buildErrorBanner(bannerMessage),
            _buildAuthCard(isGoogleLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _ErrorBanner(
        message: message,
        onClose: () {
          context.read<AuthenticationBloc>().add(const AuthenticationUserChanged(MyUser.empty));
        },
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            margin: const EdgeInsets.all(24),
            child: Material(
              elevation: 0,
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
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorBanner({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              color: theme.colorScheme.error,
              size: 20,
            ),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
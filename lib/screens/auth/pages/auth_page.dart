import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../config/constants/theme_switch.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../error/auth_error_mapper.dart';
import '../widgets/auth_header.dart';
import '../widgets/brand_panel.dart';
import '../widgets/error_banner.dart';
import '../widgets/social_buttons.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with TickerProviderStateMixin {
  String? _errorMessage;
  bool _isGoogleLoading = false;

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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

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
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      // 🎯 CHIAMA IL BLOC CHE CHIAMERÀ IL REPOSITORY
      context.read<AuthenticationBloc>().add(
        const AuthenticationGoogleSignInRequested(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante l\'accesso con Google. Riprova.';
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _handleEmailAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SignInScreen(
          providers: [
            EmailAuthProvider(),
          ],
          headerBuilder: (context, constraints, shrinkOffset) {
            return _buildEmailAuthHeader();
          },
          subtitleBuilder: (context, action) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Ti invieremo un link magico per accedere senza password.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
          actions: [
            AuthStateChangeAction<SignedIn>((context, state) {
              context.go('/');
            }),
            AuthStateChangeAction<UserCreated>((context, state) {
              context.go('/');
            }),
            AuthStateChangeAction<AuthFailed>((context, state) {
              if (mounted) {
                setState(() {
                  _errorMessage = mapAuthError(state.exception);
                });
              }
              Navigator.of(context).pop();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailAuthHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.email_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Accesso Email Magic Link',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
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
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : theme.colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 60,
                  offset: const Offset(0, 30),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                AuthHeader(
                  title: 'Benvenuto',
                  subtitle: 'Accedi a Flowchart Thesis',
                  isDark: isDark,
                  onThemeToggle: () => Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).toggleTheme(),
                ),
                const SizedBox(height: 32),

                // Error Banner
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ErrorBanner(
                      message: _errorMessage!,
                      onClose: () => setState(() => _errorMessage = null),
                    ),
                  ),

                // Social Auth Buttons
                SocialAuthButton(
                  text: 'Continua con Google',
                  icon: FontAwesomeIcons.google,
                  onPressed: _handleGoogleSignIn,
                  isLoading: _isGoogleLoading,
                  iconColor: const Color(0xFF4285F4),
                  isPrimary: true,
                ),
                SocialAuthButton(
                  text: 'Accedi con Email Magic Link',
                  icon: FontAwesomeIcons.envelope,
                  onPressed: _handleEmailAuth,
                  isLoading: false,
                ),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        thickness: 1,
                      ),
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
                      child: Divider(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Footer
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1200;

    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.status == AuthenticationStatus.authenticated) {
          context.go('/');
        }
        if (_isGoogleLoading && state.status != AuthenticationStatus.unknown) {
          setState(() => _isGoogleLoading = false);
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: SafeArea(
          child: isWide
              ? Row(
            children: [
              // Brand Panel
              const Expanded(
                flex: 5,
                child: BrandPanel(),
              ),
              // Auth Card
              Expanded(
                flex: 4,
                child: Center(child: _buildAuthCard()),
              ),
            ],
          )
              : Center(
            child: SingleChildScrollView(
              child: _buildAuthCard(),
            ),
          ),
        ),
      ),
    );
  }
}
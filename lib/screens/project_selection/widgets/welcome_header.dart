import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../config/constants/themes.dart';
import '../../../config/router/app_router.dart';
import '../../../config/services/dialog_service.dart';


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

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppStyles.borderRadiusLarge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.2),
            theme.colorScheme.secondaryContainer.withOpacity(0.1),
            theme.colorScheme.tertiaryContainer.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: AnimatedBuilder(
        animation: _heroAnimation,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _heroAnimation,
              child: Column(
                children: [
                  _buildHeroIcon(theme),
                  const SizedBox(height: 24),
                  _buildWelcomeText(theme),
                  const SizedBox(height: 12),
                  _buildSubtitle(theme),
                  const SizedBox(height: 32),
                  _buildDecorativeElements(theme),
                ],
              ),
            ),
          );
        },
      ),
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

  Widget _buildDecorativeElements(ThemeData theme) {
    return AnimatedBuilder(
      animation: _decorationAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 300 + (index * 100)),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: index == 2 ? 24 : 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: index == 2
                      ? [theme.colorScheme.primary, theme.colorScheme.secondary]
                      : [
                          theme.colorScheme.primary.withOpacity(0.3),
                          theme.colorScheme.secondary.withOpacity(0.3),
                        ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ... il resto del file (ProfileMenu) rimane invariato
class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthenticationBloc>().state.user;

    return PopupMenuButton<String>(
      tooltip: "Opzioni profilo",
      offset: const Offset(0, 55),
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'logout') {
          final confirm = await DialogService.showConfirmationDialog(context,
              title: "Logout",
              message: "Sei sicuro di voler uscire?",
              confirmText: "Esci",
              cancelText: "Annulla");
          if (confirm == true) {
            context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
          }
        } else if (value == 'settings') {
          AppRouter.goToSettings(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            const Text("Impostazioni"),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text("Logout", style: TextStyle(color: theme.colorScheme.error)),
          ]),
        ),
      ],
      child: Hero(
        tag: 'profilePicture',
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primary, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: ClipOval(
            child: user.photoURL.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: user.photoURL,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 2)),
              errorWidget: (context, url, error) => Icon(Icons.error, color: theme.colorScheme.error),
            )
                : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.surfaceContainerHighest),
              child: Icon(Icons.person_outline, size: 24, color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
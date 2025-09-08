import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../config/router/app_router.dart';
import '../../../config/services/dialog_service.dart';

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FaIcon(FontAwesomeIcons.diagramProject, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        BlocBuilder<AuthenticationBloc, AuthenticationState>(
          builder: (context, state) {
            final username = state.status == AuthenticationStatus.authenticated ? state.user.name : "Utente";
            return Text(
              "Ciao $username!",
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          // <<< MODIFICA: Sottotitolo più elegante
          "È un piacere rivederti su Flowchart Thesis",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // <<< MODIFICA: Elemento decorativo per aggiungere stile
        Container(
          margin: const EdgeInsets.only(top: 20),
          height: 3,
          width: 60,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
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
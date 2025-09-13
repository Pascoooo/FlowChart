import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../config/services/dialog_service.dart';
import '../../user_dashboard/animations/background_animation.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Impostazioni'),
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        backgroundColor: cs.surface.withAlpha(240),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Torna alla schermata precedente',
        ),
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          // Contenuto non scrollabile centrato
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: cs.outline.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withOpacity(isDark ? 0.15 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Header(),
                      SizedBox(height: 35),
                      SystemSettings(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class Header extends StatelessWidget {
  const Header();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Impostazioni Sistema',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personalizza e gestisci la tua esperienza.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class SystemSettings extends StatelessWidget {
  const SystemSettings();

  void _confirmLogout(BuildContext context) async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Conferma Logout',
      message: 'Sei sicuro di voler uscire dal tuo account?',
      confirmText: 'Logout',
      cancelText: 'Annulla',
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
    }
  }

  void _confirmAccountDeletion(BuildContext context) async {
    final bool? firstConfirmation = await DialogService.showConfirmationDialog(
      context,
      title: 'Eliminazione Account',
      message: 'Questa azione eliminerà definitivamente il tuo account',
      confirmText: 'Elimina',
      cancelText: 'Annulla',
    );

    if (firstConfirmation != true || !context.mounted) {
      return;
    }

    final bool? secondConfirmation = await DialogService.showConfirmationDialog(
      context,
      title: 'Conferma Eliminazione',
      message: 'Sei sicuro di voler eliminare il tuo account? Questa azione è irreversibile.' ,
      confirmText: 'Conferma',
      cancelText: 'Annulla',
    );

    if (secondConfirmation == true && context.mounted) {
      context.read<AuthenticationBloc>().add(const AuthenticationDeleteAccountRequested());
    }
  }

  void _confirmResetSettings(BuildContext context) async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Conferma Ripristino',
      message: 'Questa azione ripristinerà tutte le impostazioni ai valori predefiniti. Vuoi procedere?',
      confirmText: 'Ripristina',
      cancelText: 'Annulla',
    );
    if (confirmed == true && context.mounted) {
      DialogService.showInfoDialog(
        context,
        title: 'Successo',
        message: 'Impostazioni ripristinate con successo.',
        icon: Icons.check_circle_outline,
      );
    }
  }

  void _showAppInfoDialog(BuildContext context) {
    DialogService.showInfoDialog(
      context,
      title: 'Informazioni App',
      message: 'Unichart\nVersione 1.0.0\n© 2025 Unichart Inc.',
      icon: Icons.info_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SettingsSection(
      title: 'Sistema e Account',
      children: [
        SettingsTile(
          title: 'Informazioni app',
          subtitle: 'Versione, build e licenze',
          icon: Icons.info_outline_rounded,
          onTap: () => _showAppInfoDialog(context),
        ),
        SettingsTile(
          title: 'Ripristina impostazioni',
          subtitle: 'Reimposta tutte le preferenze',
          icon: Icons.restart_alt_rounded,
          onTap: () => _confirmResetSettings(context),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(indent: 16, endIndent: 16),
        ),
        SettingsTile(
          title: 'Logout',
          subtitle: 'Esci dal tuo account Unichart',
          icon: FontAwesomeIcons.rightFromBracket,
          iconColor: cs.error,
          titleColor: cs.error,
          onTap: () => _confirmLogout(context),
        ),
        SettingsTile(
          title: 'Elimina account',
          subtitle: 'Rimuovi definitivamente il tuo account',
          icon: FontAwesomeIcons.userXmark,
          iconColor: cs.error,
          titleColor: cs.error,
          onTap: () {
            _confirmAccountDeletion(context);
          },
        ),
      ],
    );
  }
}

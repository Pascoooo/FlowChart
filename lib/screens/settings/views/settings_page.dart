// lib/settings/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../config/services/dialog_service.dart';
import '../widgets/settings_provider.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_switch_tile.dart';
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
        backgroundColor: cs.surface.withAlpha(240), // Semi-transparent for a modern feel
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Torna alla schermata precedente',
        ),
      ),
      body: Container(
        // Subtle gradient background inspired by BrandPanel
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withOpacity(isDark ? 0.03 : 0.01),
              cs.surface,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: Center(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  // The main card now resembles the auth card
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(),
                        SizedBox(height: 40),
                        _GeneralSettings(),
                        SizedBox(height: 24),
                        _SystemSettings(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Header inspired by AuthHeader for consistency
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


class _GeneralSettings extends StatelessWidget {
  const _GeneralSettings();

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return SettingsSection(
      title: 'Generale',
      children: [
        SettingsSwitchTile(
          title: 'Salvataggio automatico',
          subtitle: 'Salva automaticamente le modifiche ai diagrammi',
          icon: Icons.save_alt_rounded,
          value: settingsProvider.autoSaveEnabled,
          onChanged: (v) => context.read<SettingsProvider>().updateAutoSave(v),
        ),
      ],
    );
  }
}

class _SystemSettings extends StatelessWidget {
  const _SystemSettings();

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

  void _confirmResetSettings(BuildContext context) async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Conferma Ripristino',
      message:
      'Questa azione ripristinerà tutte le impostazioni ai valori predefiniti. Vuoi procedere?',
      confirmText: 'Ripristina',
      cancelText: 'Annulla',
    );
    if (confirmed == true && context.mounted) {
      await context.read<SettingsProvider>().resetAll();
      DialogService.showInfoDialog(context, title: 'Successo', content: const Text('Impostazioni ripristinate con successo.'));
    }
  }

  void _showAppInfoDialog(BuildContext context) {
    DialogService.showInfoDialog(
      context,
      title: 'Informazioni App',
      icon: FontAwesomeIcons.diagramProject,
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unichart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 16),
          Text('Versione: 1.0.0 (Build 100)'),
          SizedBox(height: 4),
          Text('Flutter SDK: 3.24.0'),
          SizedBox(height: 16),
          Text('© 2024 Unichart Team. Tutti i diritti riservati.'),
        ],
      ),
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
      ],
    );
  }
}
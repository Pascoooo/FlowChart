// dart
// file: 'lib/screens/settings/views/SettingsPage.dart'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/constants/theme_switch.dart';
import '../widgets/SettingsSection.dart';
import '../widgets/SettingsSwitchTile.dart';
import '../widgets/SettingsTile.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _autoSaveEnabled = true;
  bool _analyticsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Impostazioni Sistema'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme, cs),
                      const SizedBox(height: 32),
                      _buildGeneralSettings(),
                      _buildAppearanceSettings(),
                      _buildSystemSettings(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.secondary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.settings, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impostazioni Sistema',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Personalizza la tua esperienza',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralSettings() {
    return SettingsSection(
      title: 'Generale',
      icon: Icons.tune,
      children: [
        const SizedBox(height: 8),
        SettingsSwitchTile(
          title: 'Salvataggio automatico',
          subtitle: 'Salva automaticamente le modifiche',
          leading: Icons.save_outlined,
          value: _autoSaveEnabled,
          onChanged: (v) => setState(() => _autoSaveEnabled = v),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return SettingsSection(
      title: 'Aspetto',
      icon: Icons.palette_outlined,
      children: [
        const SizedBox(height: 8),
        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return SettingsTile(
              title: 'Toggle tema rapido',
              subtitle: 'Cambia rapidamente tra chiaro e scuro',
              leading: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              trailing: const Icon(Icons.swap_horiz, size: 20),
              onTap: () => themeProvider.toggleTheme(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return SettingsSection(
      title: 'Sistema',
      icon: Icons.computer_outlined,
      children: [
        const SizedBox(height: 8),
        SettingsTile(
          title: 'Informazioni app',
          subtitle: 'Versione 1.0.0 • Build 100',
          leading: Icons.info_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showAppInfoDialog,
        ),
        const SizedBox(height: 8),
        SettingsTile(
          title: 'Ripristina impostazioni',
          subtitle: 'Reimposta tutte le preferenze ai valori predefiniti',
          leading: Icons.restart_alt_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _confirmResetSettings,
        ),
      ],
    );
  }

  void _confirmResetSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ripristinare le impostazioni?'),
        content: const Text(
          'Questa operazione ripristinerà tutte le preferenze ai valori predefiniti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _notificationsEnabled = true;
                _autoSaveEnabled = true;
                _analyticsEnabled = false;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impostazioni ripristinate')),
              );
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info),
            SizedBox(width: 8),
            Text('Informazioni App'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FlowChart Thesis', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Versione: 1.0.0'),
            Text('Build: 100'),
            Text('Flutter SDK: 3.24.0'),
            SizedBox(height: 12),
            Text('© 2024 FlowChart Thesis Team'),
            Text('Tutti i diritti riservati'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/constants/theme_switch.dart';
import '../widgets/SettingsTile.dart';
import '../widgets/SettingsSection.dart';
import '../widgets/SettingsSwitchTile.dart';
import '../widgets/LanguageSelector.dart';
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
  String _selectedLanguage = 'it';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Impostazioni Sistema'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
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
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Impostazioni Sistema',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Personalizza la tua esperienza',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Settings Content
                  _buildGeneralSettings(),
                  _buildAppearanceSettings(),
                  _buildPrivacySettings(),
                  _buildSystemSettings(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return SettingsSection(
      title: 'Generale',
      icon: Icons.tune,
      children: [
        LanguageSelector(
          currentLanguage: _selectedLanguage,
          onLanguageChanged: (value) => setState(() => _selectedLanguage = value),
        ),
        const SizedBox(height: 16),
        SettingsSwitchTile(
          title: 'Notifiche',
          subtitle: 'Ricevi notifiche push',
          leading: Icons.notifications_outlined,
          value: _notificationsEnabled,
          onChanged: (value) => setState(() => _notificationsEnabled = value),
        ),
        SettingsSwitchTile(
          title: 'Salvataggio automatico',
          subtitle: 'Salva automaticamente le modifiche',
          leading: Icons.save_outlined,
          value: _autoSaveEnabled,
          onChanged: (value) => setState(() => _autoSaveEnabled = value),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return SettingsSection(
      title: 'Aspetto',
      icon: Icons.palette_outlined,
      children: [
        const SizedBox(height: 16),

        Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return SettingsTile(
              title: 'Toggle tema rapido',
              subtitle: 'Cambia rapidamente tra chiaro e scuro',
              leading: Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              trailing: const Icon(Icons.swap_horiz, size: 20),
              onTap: () => themeProvider.toggleTheme(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return SettingsSection(
      title: 'Privacy e Sicurezza',
      icon: Icons.privacy_tip_outlined,
      children: [
        SettingsSwitchTile(
          title: 'Analisi utilizzo',
          subtitle: 'Condividi dati di utilizzo anonimi',
          leading: Icons.analytics_outlined,
          value: _analyticsEnabled,
          onChanged: (value) => setState(() => _analyticsEnabled = value),
        ),
        SettingsTile(
          title: 'Gestisci dati',
          subtitle: 'Esporta o elimina i tuoi dati',
          leading: Icons.folder_open_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showDataManagementDialog(),
        ),
        SettingsTile(
          title: 'Termini di servizio',
          subtitle: 'Leggi i nostri termini',
          leading: Icons.description_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showTermsDialog(),
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return SettingsSection(
      title: 'Sistema',
      icon: Icons.computer_outlined,
      children: [
        SettingsTile(
          title: 'Informazioni app',
          subtitle: 'Versione 1.0.0 • Build 100',
          leading: Icons.info_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showAppInfoDialog(),
        ),
        SettingsTile(
          title: 'Supporto',
          subtitle: 'Contatta il supporto tecnico',
          leading: Icons.help_outline,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showSupportDialog(),
        ),
        SettingsTile(
          title: 'Feedback',
          subtitle: 'Invia suggerimenti e segnalazioni',
          leading: Icons.feedback_outlined,
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showFeedbackDialog(),
        ),
      ],
    );
  }

  // I metodi per i dialoghi rimangono gli stessi...
  void _showDataManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.folder_open),
            SizedBox(width: 8),
            Text('Gestione Dati'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestisci i tuoi dati personali:'),
            SizedBox(height: 12),
            Text('• Esporta tutti i dati'),
            Text('• Elimina account'),
            Text('• Cancella cronologia'),
            SizedBox(height: 12),
            Text('Funzionalità in sviluppo.',
                style: TextStyle(fontStyle: FontStyle.italic)),
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

  void _showAppInfoDialog() {
    showDialog(
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

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help),
            SizedBox(width: 8),
            Text('Supporto'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hai bisogno di aiuto?'),
            SizedBox(height: 12),
            Text('📧 Email: support@flowchart-thesis.com'),
            Text('💬 Chat: Disponibile 24/7'),
            Text('📞 Telefono: +39 XXX XXXXXXX'),
            SizedBox(height: 12),
            Text('Il nostro team risponde entro 24 ore.'),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.description),
            SizedBox(width: 8),
            Text('Termini di Servizio'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('I nostri termini di servizio includono:'),
              SizedBox(height: 12),
              Text('• Utilizzo del servizio'),
              Text('• Privacy e protezione dati'),
              Text('• Responsabilità dell\'utente'),
              Text('• Limitazioni di responsabilità'),
              SizedBox(height: 12),
              Text('Per la versione completa, visita il nostro sito web.',
                  style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
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

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.feedback),
            SizedBox(width: 8),
            Text('Invia Feedback'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('I tuoi suggerimenti sono importanti per noi!'),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Scrivi qui il tuo feedback...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Grazie per il tuo feedback!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Invia'),
          ),
        ],
      ),
    );
  }
}
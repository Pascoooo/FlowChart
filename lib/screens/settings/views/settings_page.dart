import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image/image.dart' as img;

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../config/services/banner_service.dart';
import '../../../config/services/dialog_service/app_dialogs.dart';
import '../../../config/services/dialog_service/service_dialog.dart';
import '../../user_dashboard/animations/background_animation.dart';
import '../widgets/export_setting.dart';
import '../widgets/settings_provider.dart';
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
      duration: const Duration(milliseconds: 450),
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
    return NavigationView(
      content: ScaffoldPage(
        content: Stack(
          children: [
            const AnimatedBackground(),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Header(),
                        SizedBox(height: 16),
                        Expanded(
                          // --- MODIFICA APPLICATA: Layout a due colonne riorganizzato ---
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- COLONNA SINISTRA ---
                              Expanded(
                                flex: 1,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      ProfileSettings(),
                                      SizedBox(height: 16),
                                      CloudIntegrationSettings(),
                                      SizedBox(height: 16),
                                      AccountManagementSettings(),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // --- COLONNA DESTRA ---
                              Expanded(
                                flex: 1,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      ExportPreferencesSettings(),
                                      SizedBox(height: 16),
                                      SystemAndInfoSettings(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS PRINCIPALI (Nessuna modifica qui)
// ============================================================================

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.inactiveColor.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          HoverButton(
            onPressed: () => Navigator.of(context).pop(),
            builder: (context, states) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accentColor.withOpacity(states.isHovered ? 0.1 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(
                  FontAwesomeIcons.arrowLeft,
                  size: 16,
                  color: theme.accentColor,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.accentColor.dark, theme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.gear,
                color: theme.brightness == Brightness.dark
                    ? theme.scaffoldBackgroundColor
                    : theme.cardColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro Impostazioni',
                  style: theme.typography.title?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestisci profilo, integrazioni e preferenze',
                  style: theme.typography.body?.copyWith(
                    fontSize: 14,
                    color: theme.typography.body?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  late final TextEditingController _nameController;
  bool _isNameChanged = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthenticationBloc>().state.user;
    _nameController = TextEditingController(text: user.name);

    _nameController.addListener(() {
      final newName = _nameController.text.trim();
      final currentName = context.read<AuthenticationBloc>().state.user.name;
      final hasChanged = newName.isNotEmpty && newName != currentName;
      if (hasChanged != _isNameChanged) {
        setState(() => _isNameChanged = hasChanged);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpdatePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) {
        if (mounted) BannerService.showInfo(context, 'Selezione annullata');
        return;
      }
      final bytes = result.files.single.bytes!;
      var processed = bytes;
      try {
        final image = img.decodeImage(processed);
        if (image != null) {
          final resizedImage = img.copyResize(image, width: 1024);
          processed = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 85));
        }
      } catch (_) {}
      if (mounted) {
        context
            .read<AuthenticationBloc>()
            .add(AuthenticationPhotoUpdateRequested(processed));
      }
    } catch (_) {
      if (mounted) BannerService.showError(context, 'Selezione immagine non riuscita.');
    }
  }

  void _saveDisplayName() {
    if (!_isNameChanged) return;
    final newName = _nameController.text.trim();
    context
        .read<AuthenticationBloc>()
        .add(AuthenticationDisplayNameUpdateRequested(newName));
    setState(() => _isNameChanged = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          BannerService.showError(context, state.errorMessage!);
          context
              .read<AuthenticationBloc>()
              .add(const AuthenticationErrorCleared());
        }
      },
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          final user = state.user;
          final isLoading = state.isLoading;
          final backgroundImage = user.photoURL.isNotEmpty
              ? CachedNetworkImageProvider(user.photoURL)
              : null;

          return SettingsSection(
            title: 'Profilo Utente',
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: backgroundImage != null
                                    ? DecorationImage(
                                    image: backgroundImage, fit: BoxFit.cover)
                                    : null,
                                color: theme.accentColor.withOpacity(0.1),
                                border: Border.all(
                                  color: theme.accentColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: backgroundImage == null
                                  ? FaIcon(
                                FontAwesomeIcons.user,
                                size: 28,
                                color: theme.accentColor,
                              )
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.cardColor,
                                ),
                                child: FilledButton(
                                  onPressed: isLoading ? null : _pickAndUpdatePhoto,
                                  style: ButtonStyle(
                                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                                    shape: const WidgetStatePropertyAll(CircleBorder()),
                                  ),
                                  child: const FaIcon(
                                    FontAwesomeIcons.camera,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nome Visualizzato',
                                style: theme.typography.body?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextBox(
                                controller: _nameController,
                                enabled: !isLoading,
                                placeholder: 'Inserisci il tuo nome',
                                style: theme.typography.body,
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Email: ${user.email}',
                            style: theme.typography.body?.copyWith(
                              color: theme.typography.body?.color?.withOpacity(0.7),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: (!_isNameChanged || isLoading) ? null : _saveDisplayName,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              FaIcon(
                                FontAwesomeIcons.floppyDisk,
                                size: 14,
                              ),
                              SizedBox(width: 6),
                              Text('Salva'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// WIDGETS DELLE SEZIONI DI IMPOSTAZIONI (Refactoring)
// ============================================================================

class CloudIntegrationSettings extends StatelessWidget {
  const CloudIntegrationSettings({super.key});

  void _connectToGoogleDrive(BuildContext context) {
    context
        .read<AuthenticationBloc>()
        .add(const AuthenticationDrivePermissionRequested());
  }

  void _disconnectFromGoogleDrive(BuildContext context) async {
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Disconnetti Google Drive',
      message:
      'Sei sicuro di voler revocare i permessi? Non potrai più salvare i tuoi file su Drive.',
      confirmText: 'Disconnetti',
      cancelText: 'Annulla',
      isDestructive: true,
    );
    if (confirmed == true && context.mounted) {
      context
          .read<AuthenticationBloc>()
          .add(const AuthenticationDrivePermissionRevoked());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthenticationBloc, AuthenticationState>(
      builder: (context, state) {
        final isDriveConnected = state.user.driveConnected;
        final isLoading = state.isLoading;
        return SettingsSection(
          title: 'Integrazioni Cloud',
          status: _StatusLabel(isConnected: isDriveConnected),
          children: [
            SettingsTile(
              title: 'Google Drive',
              subtitle: isDriveConnected
                  ? 'Account collegato e sincronizzato'
                  : 'Collega il tuo account per salvare i file',
              icon: FontAwesomeIcons.googleDrive,
              iconColor: isDriveConnected
                  ? FluentTheme.of(context).resources.systemFillColorSuccess
                  : null,
              trailing: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : isDriveConnected
                    ? () => _disconnectFromGoogleDrive(context)
                    : () => _connectToGoogleDrive(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(isDriveConnected ? 'Disconnetti' : 'Connetti'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExportPreferencesSettings extends StatelessWidget {
  const ExportPreferencesSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    // --- MODIFICA APPLICATA: Aggiunto BlocConsumer per ripristinare la logica ---
    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listenWhen: (previous, current) {
        // Ascolta solo quando lo stato di connessione a Drive cambia da connesso a disconnesso.
        return previous.user.driveConnected && !current.user.driveConnected;
      },
      listener: (context, state) {
        // Se la preferenza era Drive, mostra il dialogo e reimposta.
        if (settingsProvider.exportPreference == ExportPreference.drive) {
          settingsProvider.updateExportPreference(ExportPreference.alwaysAsk);
          AppDialogs.showInfoDialog(
            context,
            title: 'Google Drive Disconnesso',
            message:
            'La preferenza di esportazione è stata cambiata a "Chiedi sempre".',
            type: DialogType.info,
          );
        }
      },
      builder: (context, state) {
        final isDriveConnected = state.user.driveConnected;
        return SettingsSection(
          title: 'Preferenze di Esportazione',
          children: [
            ExportOptionTile(
              title: 'Chiedi sempre dove salvare',
              selected: settingsProvider.exportPreference == ExportPreference.alwaysAsk,
              onTap: () => settingsProvider.updateExportPreference(ExportPreference.alwaysAsk),
            ),
            ExportOptionTile(
              title: 'Salva automaticamente sul dispositivo',
              selected: settingsProvider.exportPreference == ExportPreference.local,
              onTap: () => settingsProvider.updateExportPreference(ExportPreference.local),
            ),
            ExportOptionTile(
              title: 'Salva automaticamente su Google Drive',
              selected: settingsProvider.exportPreference == ExportPreference.drive,
              onTap: () => settingsProvider.updateExportPreference(ExportPreference.drive),
              enabled: isDriveConnected,
            ),
          ],
        );
      },
    );
  }
}

class SystemAndInfoSettings extends StatelessWidget {
  const SystemAndInfoSettings({super.key});

  void _confirmResetSettings(BuildContext context) async {
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Conferma Ripristino',
      message: 'Ripristinare tutte le impostazioni ai valori predefiniti?',
      confirmText: 'Ripristina',
      isDestructive: true
    );
    if (confirmed == true && context.mounted) {
      // Logic for reset settings would go here
      AppDialogs.showInfoDialog(context,
          title: 'Successo',
          message: 'Impostazioni ripristinate.',
          type: DialogType.success);
    }
  }

  void _showAppInfoDialog(BuildContext context) {
    AppDialogs.showInfoDialog(context,
        title: 'Informazioni App',
        message: 'Unichart\nVersione 1.0.0\n© 2025 Unichart Inc.',
        type: DialogType.info);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Sistema e Informazioni',
      children: [
        SettingsTile(
          title: 'Informazioni applicazione',
          subtitle: 'Versione, build, licenze e crediti',
          icon: FontAwesomeIcons.circleInfo,
          onTap: () => _showAppInfoDialog(context),
        ),
        SettingsTile(
          title: 'Ripristina impostazioni predefinite',
          subtitle: 'Reimposta tutte le preferenze',
          icon: FontAwesomeIcons.arrowRotateLeft,
          onTap: () => _confirmResetSettings(context),
        ),
      ],
    );
  }
}

class AccountManagementSettings extends StatelessWidget {
  const AccountManagementSettings({super.key});

  void _confirmLogout(BuildContext context) async {
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Conferma Logout',
      message: 'Sei sicuro di voler uscire?',
      confirmText: 'Logout',
      cancelText: 'Annulla',
      isDestructive: true
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
    }
  }

  void _confirmAccountDeletion(BuildContext context) async {
    final bool? confermation = await AppDialogs.showConfirmationDialog(
      context,
      title: 'Eliminazione Account',
      message: 'Questa azione eliminerà definitivamente il tuo account e tutti i dati associati.',
      confirmText: 'Elimina',
      cancelText: 'Annulla',
      isDestructive: true
    );
    if (confermation == true && context.mounted) {
      context
          .read<AuthenticationBloc>()
          .add(const AuthenticationDeleteAccountRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Gestione Account',
      children: [
        SettingsTile(
          title: 'Disconnetti dall\'account',
          subtitle: 'Esci dal tuo account Unichart',
          icon: FontAwesomeIcons.rightFromBracket,
          onTap: () => _confirmLogout(context),
          isDestructive: true,
        ),
        SettingsTile(
          title: 'Elimina account definitivamente',
          subtitle: 'Rimuovi permanentemente il tuo account',
          icon: FontAwesomeIcons.userXmark,
          onTap: () => _confirmAccountDeletion(context),
          isDestructive: true,
        ),
      ],
    );
  }
}


// ============================================================================
// STATUS LABEL - Widget di stato per le integrazioni
// ============================================================================

class _StatusLabel extends StatelessWidget {
  final bool isConnected;
  const _StatusLabel({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final color = isConnected
        ? theme.resources.systemFillColorSuccess
        : theme.resources.systemFillColorCritical;
    final text = isConnected ? 'Connesso' : 'Non Connesso';
    final icon = isConnected
        ? FontAwesomeIcons.circleCheck
        : FontAwesomeIcons.circleXmark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.typography.caption?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


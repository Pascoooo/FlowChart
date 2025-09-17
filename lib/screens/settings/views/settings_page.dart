import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../config/services/dialog_service.dart';
import '../../../config/services/banner_service.dart';
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
                  child: const SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Header(),
                        SizedBox(height: 35),
                        ProfileSettings(),
                        SizedBox(height: 20),
                        SystemSettings(),
                      ],
                    ),
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
  const Header({super.key});
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
        setState(() {
          _isNameChanged = hasChanged;
        });
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
    } catch (e) {
      if(mounted) BannerService.showError(context, 'Selezione immagine non riuscita.');
    }
  }

  void _saveDisplayName() {
    if (!_isNameChanged) return;
    final newName = _nameController.text.trim();
    context
        .read<AuthenticationBloc>()
        .add(AuthenticationDisplayNameUpdateRequested(newName));
    setState(() {
      _isNameChanged = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocListener<AuthenticationBloc, AuthenticationState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          BannerService.showError(context, state.errorMessage!);
          context.read<AuthenticationBloc>().add(const AuthenticationErrorCleared());
        }
      },
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, state) {
          final user = state.user;
          final isLoading = state.isLoading;
          final backgroundImage =
          user.photoURL.isNotEmpty ? CachedNetworkImageProvider(user.photoURL) : null;

          return SettingsSection(
            title: 'Profilo Utente',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: cs.surfaceContainerHigh,
                          backgroundImage: backgroundImage,
                          child: (backgroundImage == null && !isLoading)
                              ? FaIcon(FontAwesomeIcons.user, size: 30, color: cs.primary)
                              : null,
                        ),
                        Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: isLoading ? null : _pickAndUpdatePhoto,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: isLoading
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Icon(Icons.edit_rounded, color: cs.onPrimary, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: _nameController,
                            enabled: !isLoading,
                            decoration: InputDecoration(
                              labelText: 'Nome Visualizzato',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: (_isNameChanged && !isLoading) ? _saveDisplayName : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Salva Nome'),
                          ),
                        ],
                      ),
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

class SystemSettings extends StatelessWidget {
  const SystemSettings({super.key});

  void _connectToGoogleDrive(BuildContext context) {
    context.read<AuthenticationBloc>().add(const AuthenticationDrivePermissionRequested());
  }

  void _disconnectFromGoogleDrive(BuildContext context) async {
    final bool? confirmed = await DialogService.showConfirmationDialog(
      context,
      title: 'Disconnetti Google Drive',
      message: 'Sei sicuro di voler revocare i permessi per Google Drive? Non potrai più salvare o accedere ai tuoi file.',
      confirmText: 'Disconnetti',
      cancelText: 'Annulla',
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthenticationBloc>().add(const AuthenticationDrivePermissionRevoked());
    }
  }

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
      message: 'Questa azione eliminerà definitivamente il tuo account e tutti i dati associati.',
      confirmText: 'Elimina',
      cancelText: 'Annulla',
    );

    if (firstConfirmation != true || !context.mounted) return;

    final bool? secondConfirmation = await DialogService.showConfirmationDialog(
      context,
      title: 'Conferma Definitiva',
      message: 'Sei assolutamente sicuro? Questa azione è irreversibile.',
      confirmText: 'Conferma Eliminazione',
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

    return BlocConsumer<AuthenticationBloc, AuthenticationState>(
      listenWhen: (previous, current) {
        final didDisconnect = previous.user.driveConnected && !current.user.driveConnected;
        final hasNewError = current.errorMessage != null;
        return didDisconnect || hasNewError;
      },
      listener: (context, state) {
        if (!state.user.driveConnected) {
          final settingsProvider = context.read<SettingsProvider>();
          if (settingsProvider.exportPreference == ExportPreference.drive) {
            settingsProvider.updateExportPreference(ExportPreference.alwaysAsk);
            DialogService.showInfoDialog(
              context,
              title: 'Google Drive Disconnesso',
              message: 'Il tuo account Google Drive è stato disconnesso. La preferenza di esportazione è stata cambiata a "Chiedi sempre".',
              icon: Icons.info_outline_rounded,
            );
          }
        }
        if (state.errorMessage != null) {
          BannerService.showError(context, state.errorMessage!);
          context.read<AuthenticationBloc>().add(const AuthenticationErrorCleared());
        }
      },
      builder: (context, state) {
        final bool isDriveConnected = state.user.driveConnected;
        final isOperationLoading = state.isLoading;
        return Column(
          children: [
            SettingsSection(
              title: 'Integrazioni',
              status: _StatusLabel(isConnected: isDriveConnected),
              children: [
                if (isOperationLoading)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SettingsTile(
                    title: 'Google Drive',
                    subtitle: isDriveConnected
                        ? 'Account collegato con successo'
                        : 'Collega il tuo account per salvare i file',
                    icon: FontAwesomeIcons.googleDrive,
                    trailing: _ConnectionButton(
                      isConnected: isDriveConnected,
                      onConnect: () => _connectToGoogleDrive(context),
                      onDisconnect: () => _disconnectFromGoogleDrive(context),
                    ),
                  ),
              ],
            ),
            // La classe ExportSettings viene da 'export_setting.dart' e non necessita modifiche.
            const ExportSettings(),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Sistema',
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
                  onTap: () => _confirmAccountDeletion(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final bool isConnected;
  const _StatusLabel({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected ? Colors.green.shade600 : theme.colorScheme.error;
    final text = isConnected ? 'CONNESSO' : 'NON CONNESSO';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900, // Testo più bold
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionButton({
    required this.isConnected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected ? theme.colorScheme.error : Colors.green.shade600;
    final text = isConnected ? 'DISCONNETTI' : 'CONNETTI';
    final action = isConnected ? onDisconnect : onConnect;

    return OutlinedButton(
      onPressed: action,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}
/// Schermata Impostazioni: gestisce profilo utente, preferenze app,
/// azioni account e informazioni di sistema, integrando animazioni e BLoC.
/// Curata per il web: layout a due colonne con larghezza massima controllata.

import 'dart:async';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart'; // NECESSARIO PER FilteringTextInputFormatter

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/auth_bloc/authentication_state.dart';
import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../config/services/banner_service.dart';
import '../../../config/services/dialog_service/app_dialogs.dart';
import '../../../config/services/dialog_service/service_dialog.dart';
import '../../user_dashboard/animations/background_animation.dart';
import '../widgets/export_setting.dart';
import '../widgets/settings_provider.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Pagina principale delle impostazioni con layout a due colonne.
/// Orquestra i widget di profilo, preferenze app e gestione account.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  /// Crea lo stateful widget per la pagina impostazioni.
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// Inizializza l'animazione di fade-in per la pagina.
  /// Prepara controller e curva di easing per l'ingresso dei contenuti.
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

  /// Libera le risorse delle animazioni e cancella debounce pendenti.
  /// Evita memory leak chiudendo i controller prima della dismissione.
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Costruisce il layout web-friendly con larghezza massima e due colonne.
  /// Applica fade-in sulla pagina e separa contenuto in due pannelli scorrevoli.
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
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: const SingleChildScrollView(
                      primary: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Header(),
                          SizedBox(height: 16),
                          ProfileSettings(),
                          SizedBox(height: 16),
                          SystemAndInfoSettings(),
                          SizedBox(height: 16),
                          AccountManagementSettings(),

                        ],
                      ),
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


// ... (widget Header, ProfileSettings invariati) ...
/// Header superiore che mostra titolo pagina e pulsante back.
class Header extends StatelessWidget {
  const Header({super.key});

  /// Rende il layout del banner con pulsante indietro, icona e sottotitolo.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.inactiveColor.withValues(alpha: 0.3),
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
                  color: theme.accentColor.withValues(alpha: states.isHovered ? 0.1 : 0.05),
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
              shape: BoxShape.circle,
              color: theme.brightness == Brightness.light ? theme.cardColor : null,
              gradient: theme.brightness == Brightness.dark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.accentColor.dark,
                        theme.accentColor,
                        theme.accentColor.light,
                      ],
                    )
                  : null,
              border: theme.brightness == Brightness.light
                  ? Border.all(
                      color: theme.accentColor,
                      width: 2.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Image.asset(

                'assets/logo.png',
                fit: BoxFit.contain,
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
                    color: theme.typography.body?.color?.withValues(alpha: 0.7),
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

/// Sezione profilo: modifica nome visualizzato e foto profilo con feedback BLoC.
class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  /// Crea lo stateful widget della sezione profilo.
  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  late final TextEditingController _nameController;
  bool _isNameChanged = false;
  Timer? _nameDebounce;

  /// Inizializza controller nome e imposta listener con debounce per variazioni.
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthenticationBloc>().state.user;
    _nameController = TextEditingController(text: user.name);

    _nameController.addListener(_scheduleNameChangeCheck);
  }

  /// Libera controller e cancella eventuali debounce attivi.
  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  /// Schedula con debounce il controllo di variazione nome per evitare toggle rapidi.
  void _scheduleNameChangeCheck() {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final newName = _nameController.text.trim();
      final currentName = context.read<AuthenticationBloc>().state.user.name;
      final hasChanged = newName.isNotEmpty && newName != currentName;
      if (hasChanged != _isNameChanged) {
        setState(() => _isNameChanged = hasChanged);
      }
    });
  }

  /// Apre il picker per la foto profilo, ridimensiona e invia evento BLoC.
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

  /// Invia al BLoC la richiesta di aggiornare il display name e resetta il flag locale.
  void _saveDisplayName() {
    if (!_isNameChanged) return;
    final newName = _nameController.text.trim();
    context
        .read<AuthenticationBloc>()
        .add(AuthenticationDisplayNameUpdateRequested(newName));
    setState(() => _isNameChanged = false);
  }

  /// Costruisce la UI del profilo con avatar, textbox e pulsante salva reattivo.
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
                                color: theme.accentColor.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: theme.accentColor.withValues(alpha: 0.3),
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
                              color: theme.typography.body?.color?.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: (!_isNameChanged || isLoading) ? null : _saveDisplayName,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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


/// Sezione sistema e info app.
class SystemAndInfoSettings extends StatelessWidget {
  const SystemAndInfoSettings({super.key});


  /// Mostra un dialog informativo con versione e crediti dell'app.
  void _showAppInfoDialog(BuildContext context) {
    AppDialogs.showInfoDialog(context,
        title: 'Informazioni App',
        message: 'Unichart\nVersione 1.0.0\n(c) 2025 Unichart Inc.\nDeveloped by:\nNicolo\' Pacucci & Andrea Pantaleo',
        type: DialogType.info);
  }

  /// Costruisce il gruppo con la voce informazioni applicazione.
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
      ],
    );
  }
}

class AccountManagementSettings extends StatelessWidget {
  const AccountManagementSettings({super.key});

  /// Esegue pulizia di stato locale e invia logout all'AuthenticationBloc.
  void _performLogoutCleanup(BuildContext context) {
    final projectBloc = context.read<ProjectBloc>();
    projectBloc.add(const LeaveProject());
    context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
  }

  /// Chiede conferma logout, quindi pulisce bloc/prov e invia evento di logout.
  void _confirmLogout(BuildContext context) async {
    final bool? confirmed = await AppDialogs.showConfirmationDialog(
        context,
        title: 'Conferma Logout',
        message: 'Sei sicuro di voler uscire?',
        confirmText: 'Logout',
        cancelText: 'Annulla',
        isDestructive: true);
    if (confirmed == true && context.mounted) {
      _performLogoutCleanup(context);
    }
  }

  /// Chiede conferma di eliminazione account e inoltra al BLoC di autenticazione.
  void _confirmAccountDeletion(BuildContext context) async {
    final bool? confirmation = await AppDialogs.showConfirmationDialog(
        context,
        title: 'Eliminazione Account',
        message: "Questa azione eliminera' definitivamente il tuo account e tutti i dati associati.",
        confirmText: 'Elimina',
        cancelText: 'Annulla',
        isDestructive: true);
    if (confirmation == true && context.mounted) {
      context
          .read<AuthenticationBloc>()
          .add(const AuthenticationDeleteAccountRequested());
    }
  }

  /// Costruisce le voci di logout e cancellazione account.
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

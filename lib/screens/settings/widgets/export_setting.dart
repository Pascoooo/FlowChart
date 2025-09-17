// lib/screens/settings/widgets/export_setting.dart
import 'package:flowchart_thesis/screens/settings/widgets/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import 'settings_section.dart';

/// **Widget di Impostazioni Esportazione con Design System Cupertino**
///
/// Questo widget è stato completamente ridisegnato per utilizzare componenti nativi
/// di Cupertino, offrendo un'esperienza utente in linea con le impostazioni di iOS.
/// Utilizza `CupertinoListSection.insetGrouped` per il layout e `CupertinoListTile`
/// per le singole opzioni, garantendo un aspetto pulito e professionale.
class ExportSettings extends StatelessWidget {
  const ExportSettings({super.key});

  @override
  Widget build(BuildContext context) {
    // Utilizza un Consumer per reagire ai cambiamenti del SettingsProvider
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        // Ottiene lo stato di autenticazione per verificare la connessione a Drive
        final authState = context.watch<AuthenticationBloc>().state;
        final isDriveConnected = authState.user.driveConnected;
        final currentPref = settingsProvider.exportPreference;

        return SettingsSection(
          title: 'Preferenze di Esportazione',
          children: [
            // Sezione in stile iOS per le opzioni di esportazione.
            // Il `backgroundColor` trasparente permette di ereditare lo sfondo
            // del contenitore genitore, mantenendo la coerenza visiva.
            CupertinoListSection.insetGrouped(
              backgroundColor: Colors.transparent,
              margin: EdgeInsets.zero,
              children: [
                _buildExportOptionTile(
                  context: context,
                  title: 'Chiedi sempre',
                  isSelected: currentPref == ExportPreference.alwaysAsk,
                  onTap: () => settingsProvider
                      .updateExportPreference(ExportPreference.alwaysAsk),
                ),
                _buildExportOptionTile(
                  context: context,
                  title: 'Salva sul dispositivo',
                  isSelected: currentPref == ExportPreference.local,
                  onTap: () => settingsProvider
                      .updateExportPreference(ExportPreference.local),
                ),
                _buildExportOptionTile(
                  context: context,
                  title: 'Salva su Google Drive',
                  isSelected: currentPref == ExportPreference.drive,
                  // L'onTap è nullo se Drive non è connesso, disabilitando il tile.
                  onTap: isDriveConnected
                      ? () => settingsProvider
                      .updateExportPreference(ExportPreference.drive)
                      : null,
                  // Proprietà esplicita per gestire lo stato visivo.
                  isEnabled: isDriveConnected,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Costruisce un singolo tile di opzione in stile Cupertino.
  ///
  /// [context]: Il BuildContext per accedere al tema.
  /// [title]: Il testo da visualizzare nel tile.
  /// [isSelected]: Determina se visualizzare l'icona di spunta.
  /// [onTap]: La callback da eseguire al tocco. Se null, il tile è disabilitato.
  /// [isEnabled]: Controlla lo stile visivo (es. colore del testo).
  Widget _buildExportOptionTile({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    // Risolve i colori dinamicamente per adattarsi al tema light/dark di Cupertino.
    final primaryColor =
    CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);
    final disabledColor =
    CupertinoDynamicColor.resolve(CupertinoColors.inactiveGray, context);

    return CupertinoListTile(
      title: Text(
        title,
        style: TextStyle(
          // Il colore del testo cambia se il tile è disabilitato.
          color: isEnabled ? null : disabledColor,
        ),
      ),
      onTap: onTap,
      // L'icona di spunta appare a sinistra (leading) solo se l'opzione è selezionata.
      leading: SizedBox(
        // Un `SizedBox` con larghezza fissa garantisce che i titoli siano
        // perfettamente allineati verticalmente, con o senza icona.
        width: 30,
        child: isSelected
            ? Icon(
          FontAwesomeIcons.check,
          color: primaryColor,
          size: 22,
        )
            : null,
      ),
    );
  }
}
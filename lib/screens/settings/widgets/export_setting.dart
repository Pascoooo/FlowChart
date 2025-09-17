// dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import 'settings_provider.dart';
import 'settings_section.dart';

class ExportSettings extends StatelessWidget {
  const ExportSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final authState = context.watch<AuthenticationBloc>().state;
        final isDriveConnected = authState.user.driveConnected;
        final currentPref = settingsProvider.exportPreference;

        return SettingsSection(
          title: 'Preferenze di Esportazione',
          children: [
            // Cerchietti a sinistra (radio custom) per selezione esclusiva
            _ExportOptionTile(
              title: 'Chiedi sempre',
              selected: currentPref == ExportPreference.alwaysAsk,
              onTap: () => settingsProvider.updateExportPreference(ExportPreference.alwaysAsk),
            ),
            _ExportOptionTile(
              title: 'Salva sul dispositivo',
              selected: currentPref == ExportPreference.local,
              onTap: () => settingsProvider.updateExportPreference(ExportPreference.local),
            ),
            _ExportOptionTile(
              title: 'Salva su Google Drive',
              selected: currentPref == ExportPreference.drive,
              onTap: isDriveConnected
                  ? () => settingsProvider.updateExportPreference(ExportPreference.drive)
                  : null,
              enabled: isDriveConnected,
              trailing: Icon(
                FontAwesomeIcons.googleDrive,
                color: isDriveConnected ? Colors.green : Theme.of(context).disabledColor,
                size: 18,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  const _ExportOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabledColor = Theme.of(context).disabledColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _RadioDot(
                selected: selected,
                color: enabled ? cs.primary : disabledColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: enabled ? cs.onSurface : disabledColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  final Color color;

  const _RadioDot({required this.selected, required this.color});

  @override
  Widget build(BuildContext context) {
    // Recupera il colore di sfondo della superficie dal tema corrente
    final surfaceColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

    const double outerSize = 15.0;
    const double outerBorder = 2.0;
    const double whiteRing = 1.5; // spessore del bordo "vuoto"

    final double innerDiameter = outerSize - 2 * outerBorder;
    final double fillSize = innerDiameter - 2 * whiteRing;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anello esterno colorato
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: outerBorder),
            ),
          ),
          // Disco che crea il bordo tra anello esterno e riempimento.
          // Ora usa il colore della superficie per mimetizzarsi.
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? innerDiameter : 0,
            height: selected ? innerDiameter : 0,
            decoration: BoxDecoration(
              color: surfaceColor, // <-- MODIFICA CHIAVE
              shape: BoxShape.circle,
            ),
          ),
          // Riempimento colorato più piccolo
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: selected ? fillSize : 0,
            height: selected ? fillSize : 0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

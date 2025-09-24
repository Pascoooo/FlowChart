import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../screens/settings/widgets/settings_provider.dart';
import '../banner_service.dart';
import '../export_service.dart';

class ShareDialogs {
  static Future<void> showExportLocationDialog({
    required BuildContext context,
    required Uint8List pngBytes,
    required String fileName,
  }) {
    void handleExport(BuildContext dialogContext, ExportPreference choice,
        bool shouldRemember) {
      if (shouldRemember) {
        dialogContext.read<SettingsProvider>().updateExportPreference(choice);
      }
      Navigator.of(dialogContext).pop();

      if (choice == ExportPreference.local) {
        ExportService.downloadFileWithDialog(
            context: context, bytes: pngBytes, fileName: fileName);
      } else if (choice == ExportPreference.drive) {
        context.read<AuthenticationBloc>().add(
          ExportFlowchartToDriveRequested(
              fileName: '$fileName.png', fileBytes: pngBytes),
        );
      }
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDriveConnected =
            dialogContext.watch<AuthenticationBloc>().state.user.driveConnected;
        bool rememberChoice = false;

        // --- REFACTOR: Sostituito CupertinoAlertDialog con un Dialog personalizzato per un'estetica superiore. ---
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Salva Esportazione',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Scegli dove salvare il diagramma.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // --- UI/UX: Le opzioni sono ora più grandi e chiare. ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildExportOptionButton(
                          context: context,
                          icon: FontAwesomeIcons.computer,
                          label: 'Dispositivo',
                          onTap: () => handleExport(dialogContext,
                              ExportPreference.local, rememberChoice),
                        ),
                        const SizedBox(width: 24),
                        _buildExportOptionButton(
                          context: context,
                          icon: FontAwesomeIcons.googleDrive,
                          label: 'Google Drive',
                          isEnabled: isDriveConnected,
                          onTap: () => handleExport(dialogContext,
                              ExportPreference.drive, rememberChoice),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // --- REFACTOR: Il widget checkbox è stato ridisegnato e pulito. ---
                    _buildRememberChoiceCheckbox(
                      context: context,
                      value: rememberChoice,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => rememberChoice = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'Annulla',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- REFACTOR: Il widget è ora completamente guidato dal tema e ha un aspetto più moderno. ---
  static Widget _buildExportOptionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    final color = isEnabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.38);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              FaIcon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // --- REFACTOR: Il checkbox personalizzato è stato sostituito con un widget standard per semplicità e coerenza. ---
  static Widget _buildRememberChoiceCheckbox({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Ricorda la mia scelta'),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: value
              ? Padding(
            padding:
            const EdgeInsets.only(top: 8.0, left: 16, right: 16),
            child: Text(
              'Potrai cambiarlo in seguito dalle impostazioni dell\'applicazione.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  static Future<void> showAdvancedShareDialog({
    required BuildContext context,
    required MyProject project,
    required VoidCallback onMakePublic,
  }) async {
    final now = DateTime.now();
    final lastUpdate = project.lastVisibilityChange;

    bool canMakePublic = true;
    Duration? remainingTime;
    const String timeLimitMessage = '24 ore';
    const Duration productionLimit = Duration(hours: 24); // Valore più realistico

    if (lastUpdate != null) {
      final difference = now.difference(lastUpdate);
      if (difference < productionLimit) {
        canMakePublic = false;
        remainingTime = productionLimit - difference;
      }
    }

    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CupertinoShareDialog(
        project: project,
        onMakePublic: onMakePublic,
        canMakePublic: canMakePublic,
        remainingTime: remainingTime,
        timeLimitMessage: timeLimitMessage,
      ),
    );
  }

  // --- DESCRIZIONE DELLA MODIFICA: Questo dialogo è stato mantenuto come CupertinoAlertDialog ma con stile rifinito. ---
  static Future<void> showInfoWithCopyableText({
    required BuildContext context,
    required String title,
    required String message,
    required String copyableText,
  }) {
    final theme = Theme.of(context);

    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.circleInfo,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ID Progetto:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '••••••••••••••••••••',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      minSize: 0,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: copyableText));
                        BannerService.showSuccess(
                            context, 'Copiato negli appunti!');
                      },
                      child: FaIcon(
                        FontAwesomeIcons.copy,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(
              'Chiudi',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// --- REFACTOR: Widget interno con stile rifinito per essere 100% guidato dal tema. ---
class _CupertinoShareDialog extends StatefulWidget {
  final MyProject project;
  final VoidCallback onMakePublic;
  final bool canMakePublic;
  final Duration? remainingTime;
  final String timeLimitMessage;

  const _CupertinoShareDialog({
    required this.project,
    required this.onMakePublic,
    required this.canMakePublic,
    required this.timeLimitMessage,
    this.remainingTime,
  });

  @override
  State<_CupertinoShareDialog> createState() => _CupertinoShareDialogState();
}

class _CupertinoShareDialogState extends State<_CupertinoShareDialog> {
  bool _isIdCopied = false;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return "${twoDigits(hours)}h ${twoDigits(minutes)}m";
    } else if (minutes > 0) {
      return "${twoDigits(minutes)}m ${twoDigits(seconds)}s";
    } else {
      return "$seconds s";
    }
  }

  void _handleCopyId() {
    Clipboard.setData(ClipboardData(text: widget.project.projectId));
    BannerService.showSuccess(context, 'ID del progetto copiato!');
    setState(() => _isIdCopied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dialogo per limite raggiunto
    if (!widget.canMakePublic) {
      return CupertinoAlertDialog(
        title: Row(
          children: [
            FaIcon(FontAwesomeIcons.clock, size: 20, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Expanded(child: Text('Limite di Modifica')),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Puoi cambiare la visibilità solo una volta ogni ${widget.timeLimitMessage}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (widget.remainingTime != null)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.hourglass, size: 14, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Riprova tra: ${_formatDuration(widget.remainingTime!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Ho Capito', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // Dialogo principale
    return CupertinoAlertDialog(
      title: Row(
        children: [
          FaIcon(FontAwesomeIcons.shareNodes, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Rendi Progetto Pubblico')),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                children: [
                  const TextSpan(text: 'Copia l\'ID per abilitare la condivisione. Chiunque lo possieda potrà visualizzare '),
                  TextSpan(
                    text: '"${widget.project.name}"',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isIdCopied
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isIdCopied
                      ? theme.colorScheme.primary.withOpacity(0.4)
                      : theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '••••••••••••••••••••',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minSize: 0,
                    onPressed: _handleCopyId,
                    child: FaIcon(
                      _isIdCopied ? FontAwesomeIcons.check : FontAwesomeIcons.copy,
                      size: 16,
                      color: _isIdCopied ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text('Annulla', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _isIdCopied
              ? () {
            widget.onMakePublic();
            Navigator.of(context).pop();
          }
              : null,
          child: Text(
            'Rendi Pubblico',
            style: TextStyle(
              color: _isIdCopied
                  ? theme.colorScheme.primary
                  : theme.disabledColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
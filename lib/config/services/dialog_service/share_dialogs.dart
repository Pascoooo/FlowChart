import 'dart:async';
import 'dart:typed_data';
import 'package:fluent_ui/fluent_ui.dart';
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
    // La logica di gestione rimane invariata
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
        final theme = FluentTheme.of(dialogContext);
        final isDriveConnected =
            dialogContext.watch<AuthenticationBloc>().state.user.driveConnected;
        bool rememberChoice = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              constraints: const BoxConstraints(
                minWidth: 580,
                maxWidth: 640,
                minHeight: 420,
              ),
              content: Container(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🎯 Header Section
                    _buildDialogHeader(
                      context: context,
                      icon: FontAwesomeIcons.fileExport,
                      iconColor:
                          theme.accentColor.defaultBrushFor(theme.brightness),
                      title: 'Salva Esportazione',
                      subtitle: 'Scegli dove salvare il diagramma esportato.',
                    ),

                    const SizedBox(height: 40),

                    // 🎯 Export Options - Web-Optimized Layout
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildExportChoiceCard(
                          context: context,
                          icon: FontAwesomeIcons.computer,
                          title: 'Dispositivo Locale',
                          subtitle: 'Scarica sul tuo computer',
                          isEnabled: true,
                          onPressed: () => handleExport(dialogContext,
                              ExportPreference.local, rememberChoice),
                        ),
                        const SizedBox(width: 24),
                        _buildExportChoiceCard(
                          context: context,
                          icon: FontAwesomeIcons.googleDrive,
                          title: 'Google Drive',
                          subtitle: isDriveConnected
                              ? 'Salva nel cloud'
                              : 'Account non connesso',
                          isEnabled: isDriveConnected,
                          onPressed: () => handleExport(dialogContext,
                              ExportPreference.drive, rememberChoice),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // 🎯 Divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: theme.resources.dividerStrokeColorDefault,
                    ),

                    const SizedBox(height: 24),

                    // 🎯 Remember Choice Section
                    _buildRememberChoiceSection(
                      context: context,
                      value: rememberChoice,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => rememberChoice = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                // 🎯 Web-Optimized Actions
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  child: Button(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text('Annulla'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🎨 Export Choice Card - Professional Design
  static Widget _buildExportChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: isEnabled ? onPressed : null,
      builder: (context, states) {
        final isHovering = states.contains(ButtonStates.hovered);
        final isPressed = states.contains(ButtonStates.pressed);
        final isDisabled = states.contains(ButtonStates.disabled);

        Color cardColor;
        Color borderColor;
        double elevation;

        if (isDisabled) {
          cardColor = theme.resources.cardBackgroundFillColorDefault;
          borderColor = theme.resources.cardStrokeColorDefault;
          elevation = 0;
        } else if (isPressed) {
          cardColor = theme.resources.cardBackgroundFillColorSecondary;
          borderColor = theme.accentColor.defaultBrushFor(theme.brightness);
          elevation = 1;
        } else if (isHovering) {
          cardColor = theme.resources.cardBackgroundFillColorSecondary;
          borderColor = theme.accentColor.defaultBrushFor(theme.brightness);
          elevation = 4;
        } else {
          cardColor = theme.resources.cardBackgroundFillColorDefault;
          borderColor = theme.resources.cardStrokeColorDefault;
          elevation = 2;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            color: cardColor,
            border: Border.all(
              color: borderColor,
              width: isHovering || isPressed ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                offset: Offset(0, elevation),
                blurRadius: elevation * 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                FaIcon(
                  icon,
                  size: 32,
                  color: isEnabled
                      ? (isHovering
                          ? theme.accentColor.defaultBrushFor(theme.brightness)
                          : theme.resources.textFillColorPrimary)
                      : theme.resources.textFillColorDisabled,
                ),

                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: theme.typography.bodyStrong?.copyWith(
                    color: isEnabled
                        ? theme.resources.textFillColorPrimary
                        : theme.resources.textFillColorDisabled,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Subtitle
                Text(
                  subtitle,
                  style: theme.typography.caption?.copyWith(
                    color: isEnabled
                        ? theme.resources.textFillColorSecondary
                        : theme.resources.textFillColorDisabled,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🎯 Remember Choice Section - Enhanced UX
  static Widget _buildRememberChoiceSection({
    required BuildContext context,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    final theme = FluentTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Checkbox Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              checked: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Ricorda la mia scelta per le prossime volte',
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorPrimary,
                ),
              ),
            ),
          ],
        ),

        // Animated Info Text
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: value
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.resources.cardBackgroundFillColorSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.resources.cardStrokeColorDefault,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.circleInfo,
                          size: 14,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Potrai modificare questa impostazione in seguito dalle impostazioni.',
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// 📢 Advanced Share Dialog - Professional Implementation
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
    const Duration productionLimit = Duration(hours: 24);

    if (lastUpdate != null) {
      final difference = now.difference(lastUpdate);
      if (difference < productionLimit) {
        canMakePublic = false;
        remainingTime = productionLimit - difference;
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _FluentShareDialog(
        project: project,
        onMakePublic: onMakePublic,
        canMakePublic: canMakePublic,
        remainingTime: remainingTime,
        timeLimitMessage: timeLimitMessage,
      ),
    );
  }

  /// ℹ️ Info Dialog with Copyable Text - Enhanced Design
  static Future<void> showInfoWithCopyableText({
    required BuildContext context,
    required String title,
    required String message,
    required String copyableText,
  }) {
    final theme = FluentTheme.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        constraints: const BoxConstraints(
          minWidth: 480,
          maxWidth: 560,
        ),
        content: Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              _buildDialogHeader(
                context: context,
                icon: FontAwesomeIcons.circleInfo,
                iconColor: theme.accentColor.defaultBrushFor(theme.brightness),
                title: title,
              ),

              const SizedBox(height: 24),

              // Message
              Text(
                message,
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Copyable Text Box - Enhanced
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.resources.textFillColorPrimary,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextBox(
                  controller:
                      TextEditingController(text: '••••••••••••••••••••'),
                  readOnly: true,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: theme.resources.textFillColorPrimary,
                  ),
                  decoration: WidgetStateProperty.resolveWith<BoxDecoration>(
                    (states) => BoxDecoration(
                      color: theme.resources.cardBackgroundFillColorSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.copy,
                        size: 16,
                        color: theme.resources.textFillColorSecondary,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: copyableText));
                        BannerService.showSuccess(
                            context, 'Copiato negli appunti!');
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 8),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text('Chiudi'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Dialog Header - Reusable Component
  static Widget _buildDialogHeader({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
  }) {
    final theme = FluentTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(
            icon,
            size: 28,
            color: iconColor,
          ),
        ),

        const SizedBox(height: 20),

        // Title
        Text(
          title,
          style: theme.typography.title?.copyWith(
            color: theme.resources.textFillColorPrimary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        // Subtitle
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// 🔒 Share Dialog - Professional Implementation
class _FluentShareDialog extends StatefulWidget {
  final MyProject project;
  final VoidCallback onMakePublic;
  final bool canMakePublic;
  final Duration? remainingTime;
  final String timeLimitMessage;

  const _FluentShareDialog({
    required this.project,
    required this.onMakePublic,
    required this.canMakePublic,
    required this.timeLimitMessage,
    this.remainingTime,
  });

  @override
  State<_FluentShareDialog> createState() => _FluentShareDialogState();
}

class _FluentShareDialogState extends State<_FluentShareDialog> {
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
    final theme = FluentTheme.of(context);

    // 🚫 Rate Limit Dialog
    if (!widget.canMakePublic) {
      return ContentDialog(
        constraints: const BoxConstraints(
          minWidth: 480,
          maxWidth: 560,
        ),
        content: Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Center(
                child: ShareDialogs._buildDialogHeader(
                  context: context,
                  icon: FontAwesomeIcons.clock,
                  iconColor: theme.resources.systemFillColorCritical,
                  title: 'Limite Temporale Raggiunto',
                  subtitle:
                      'Devi attendere prima di poter modificare nuovamente la visibilità.',
                ),
              ),

              const SizedBox(height: 24),

              // Info Message
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.resources.systemFillColorCritical
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.resources.systemFillColorCritical
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Puoi cambiare la visibilità solo una volta ogni ${widget.timeLimitMessage}.',
                    style: theme.typography.body?.copyWith(
                      color: theme.resources.textFillColorPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Countdown Timer
              if (widget.remainingTime != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.resources.systemFillColorCritical,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.hourglass,
                          size: 16,
                          color: theme.brightness == Brightness.light
                              ? Colors.white
                              : Colors.black,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Riprova tra: ${_formatDuration(widget.remainingTime!)}',
                          style: theme.typography.bodyStrong?.copyWith(
                            color: theme.brightness == Brightness.light
                                ? Colors.white
                                : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  child: Text('Ho Capito'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ Main Share Dialog
    return ContentDialog(
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 600,
      ),
      content: Container(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            ShareDialogs._buildDialogHeader(
              context: context,
              icon: FontAwesomeIcons.shareNodes,
              iconColor: theme.accentColor.defaultBrushFor(theme.brightness),
              title: 'Rendi Progetto Pubblico',
              subtitle:
                  'Genera un ID di condivisione per permettere ad altri di visualizzare il progetto.',
            ),

            const SizedBox(height: 24),

            // Project Name Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.resources.cardBackgroundFillColorSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.typography.body?.copyWith(
                    color: theme.resources.textFillColorPrimary,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Chiunque possieda l\'ID potrà visualizzare ',
                    ),
                    TextSpan(
                      text: '"${widget.project.name}"',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            theme.accentColor.defaultBrushFor(theme.brightness),
                      ),
                    ),
                    const TextSpan(text: ' in modalità di sola lettura.'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ID Copy Section - Enhanced
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID Progetto',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: theme.resources.textFillColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isIdCopied
                          ? theme.resources.systemFillColorSuccess
                          : theme.resources.textOnAccentFillColorPrimary,
                      width: _isIdCopied ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextBox(
                    controller:
                        TextEditingController(text: '••••••••••••••••••••'),
                    readOnly: true,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: theme.resources.textFillColorPrimary,
                    ),
                    decoration: WidgetStateProperty.resolveWith<BoxDecoration>(
                      (states) => BoxDecoration(
                        color: theme.resources.cardBackgroundFillColorSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: FaIcon(
                          _isIdCopied
                              ? FontAwesomeIcons.check
                              : FontAwesomeIcons.copy,
                          size: 16,
                          color: _isIdCopied
                              ? theme.resources.systemFillColorSuccess
                              : theme.resources.textFillColorSecondary,
                        ),
                        onPressed: _handleCopyId,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Copy Status Indicator
            if (_isIdCopied)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.check,
                      size: 14,
                      color: theme.resources.systemFillColorSuccess,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ID copiato! Ora puoi rendere pubblico il progetto.',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.systemFillColorSuccess,
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
        // Secondary Action
        Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 8),
          child: Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('Annulla'),
            ),
          ),
        ),

        // Primary Action
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 8),
          child: FilledButton(
            onPressed: _isIdCopied
                ? () {
                    widget.onMakePublic();
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text('Rendi Pubblico'),
            ),
          ),
        ),
      ],
    );
  }
}

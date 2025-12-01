import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';
import '../../../screens/user_dashboard/project_selection/widgets/flowchart_preview.dart';

enum RecoveryAction { manage, discard }

/// 🔄 Professional Recovery Dialog System - Web-First Design
class RecoveryDialogs {
  /// 🚨 Initial Recovery Choice Dialog - Perfectly Centered
  static Future<RecoveryAction?> showInitialRecoveryDialog({
    required BuildContext context,
    required String projectName,
  }) {
    final theme = FluentTheme.of(context);

    return showDialog<RecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Center(
          child: ContentDialog(
            constraints: const BoxConstraints(
              minWidth: 580,
              maxWidth: 640,
              minHeight: 320,
            ),
            content: Container(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🎯 Header Section - Centered
                  Column(
                    children: [
                      // Warning Icon Container
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (theme.brightness == Brightness.light
                              ? const Color(0xFFD97706) // Warning color light
                              : const Color(0xFFF59E0B)  // Warning color dark
                          ).withValues(alpha: 0.1),
                          border: Border.all(
                            color: (theme.brightness == Brightness.light
                                ? const Color(0xFFD97706)
                                : const Color(0xFFF59E0B)
                            ).withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.triangleExclamation,
                          size: 32,
                          color: theme.brightness == Brightness.light
                              ? const Color(0xFFD97706)
                              : const Color(0xFFF59E0B),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Modifiche non Salvate Rilevate',
                        style: theme.typography.title?.copyWith(
                          color: theme.typography.body?.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🎯 Divider
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: theme.resources.dividerStrokeColorDefault,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),

                  const SizedBox(height: 20),

                  // 🎯 Message - Centered with Project Name Highlight
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: theme.typography.body?.copyWith(
                          color: theme.typography.body?.color?.withValues(alpha: 0.8),
                          height: 1.6,
                          fontSize: 15,
                        ),
                        children: [
                          const TextSpan(
                            text: 'È stata trovata una sessione di lavoro precedente non salvata per il progetto ',
                          ),
                          TextSpan(
                            text: '"$projectName"',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.accentColor.defaultBrushFor(theme.brightness),
                            ),
                          ),
                          const TextSpan(
                            text: '. Puoi rivedere le modifiche per recuperarle o scartarle definitivamente.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // 🎯 Actions - Centered Row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Secondary Action - Discard
                    Button(
                      onPressed: () => Navigator.of(dialogContext).pop(RecoveryAction.discard),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Scarta Modifiche'),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Primary Action - Manage
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(RecoveryAction.manage),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Rivedi e Gestisci'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔍 Manual Recovery Dialog - Professional Comparison Interface
  static Future<bool?> showManualRecoveryDialog({
    required BuildContext context,
    required UnsavedChangesFound state,
  }) {
    final projectBloc = context.read<ProjectBloc>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: projectBloc,
        child: _ManualRecoveryDialog(state: state),
      ),
    );
  }
}

// --- INTERNAL WIDGETS ---

/// 🔄 Manual Recovery Dialog - Stateful Management
class _ManualRecoveryDialog extends StatefulWidget {
  final UnsavedChangesFound state;
  const _ManualRecoveryDialog({required this.state});

  @override
  State<_ManualRecoveryDialog> createState() => _ManualRecoveryDialogState();
}

class _ManualRecoveryDialogState extends State<_ManualRecoveryDialog> {
  late List<UnsavedFileChange> _remainingFiles;

  @override
  void initState() {
    super.initState();
    _remainingFiles = List.from(widget.state.changedFiles);
  }

  void _handleDecision() {
    setState(() {
      if (_remainingFiles.isNotEmpty) _remainingFiles.removeAt(0);
      if (_remainingFiles.isEmpty) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentFile = _remainingFiles.first;
    final totalFiles = widget.state.changedFiles.length;
    final processedCount = totalFiles - _remainingFiles.length + 1;

    return ContentDialog(
      style: const ContentDialogThemeData(padding: EdgeInsets.zero),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        minWidth: 1000,
        minHeight: 600,
      ),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _RecoveryComparisonLayout(
          key: ValueKey(currentFile.fileId),
          fileName: currentFile.fileName,
          progressText: '$processedCount di $totalFiles',
          firestoreContent: currentFile.firestoreContent,
          rtdbContent: currentFile.rtdbContent,
          onKeepSaved: () {
            context.read<ProjectBloc>().add(DiscardSingleFileChange(
                projectId: widget.state.projectId,
                fileId: currentFile.fileId));
            _handleDecision();
          },
          onRecoverLocal: () {
            context.read<ProjectBloc>().add(RecoverSingleFile(
                projectId: widget.state.projectId,
                fileId: currentFile.fileId,
                rtdbContent: currentFile.rtdbContent));
            _handleDecision();
          },
        ),
      ),
    );
  }
}

/// 🎨 Recovery Comparison Layout - Professional Design
class _RecoveryComparisonLayout extends StatelessWidget {
  final String fileName;
  final String progressText;
  final String firestoreContent;
  final String rtdbContent;
  final VoidCallback onKeepSaved;
  final VoidCallback onRecoverLocal;

  const _RecoveryComparisonLayout({
    super.key,
    required this.fileName,
    required this.progressText,
    required this.firestoreContent,
    required this.rtdbContent,
    required this.onKeepSaved,
    required this.onRecoverLocal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      children: [
        // 🎯 Header Section - Professional Design
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: theme.resources.layerFillColorDefault,
            border: Border(
              bottom: BorderSide(
                color: theme.resources.dividerStrokeColorDefault,
                width: 1,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Centered Title and File Name
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confronta Versioni',
                    style: theme.typography.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: theme.typography.title?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              // Progress indicator on the right
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.resources.subtleFillColorSecondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'File $progressText',
                    style: theme.typography.caption,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 🎯 Comparison Content - Two Column Layout
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column - Saved Version
                _buildVersionColumn(
                  context: context,
                  title: "Versione Salvata (Cloud)",
                  subtitle: "Ultima versione salvata nel cloud",
                  icon: FontAwesomeIcons.cloud,
                  iconColor: theme.brightness == Brightness.light
                      ? const Color(0xFF0284C7) // Info color light
                      : const Color(0xFF06BEE1), // Info color dark
                  content: firestoreContent,
                  buttonText: "Conserva Versione Salvata",
                  isSecondary: true,
                  onPressed: onKeepSaved,
                ),

                const SizedBox(width: 32),

                // Right Column - Local Version
                _buildVersionColumn(
                  context: context,
                  title: "Versione Locale (Non Salvata)",
                  subtitle: "Modifiche locali non salvate",
                  icon: FontAwesomeIcons.floppyDisk,
                  iconColor: theme.brightness == Brightness.light
                      ? const Color(0xFFD97706) // Warning color light
                      : const Color(0xFFF59E0B), // Warning color dark
                  content: rtdbContent,
                  buttonText: "Recupera Modifiche Locali",
                  showUnsavedBadge: true,
                  isSecondary: false,
                  onPressed: onRecoverLocal,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 🎨 Version Column - Enhanced Design Component
  Widget _buildVersionColumn({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String content,
    required String buttonText,
    required bool isSecondary,
    required VoidCallback onPressed,
    bool showUnsavedBadge = false,
  }) {
    final theme = FluentTheme.of(context);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.resources.cardStrokeColorDefault,
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.resources.cardBackgroundFillColorDefault,
        ),
        child: Column(
          children: [
            // Column Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.resources.layerFillColorAlt,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Icon and Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: FaIcon(
                          icon,
                          size: 16,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.typography.bodyStrong?.copyWith(
                                color: theme.typography.body?.color,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.typography.caption?.copyWith(
                                color: theme.typography.body?.color?.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Preview Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FlowchartPreview(
                  flowchartContent: content,
                  showUnsavedBadge: showUnsavedBadge,
                ),
              ),
            ),

            // Action Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: isSecondary
                    ? Button(
                  onPressed: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                    : FilledButton(
                  onPressed: onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
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

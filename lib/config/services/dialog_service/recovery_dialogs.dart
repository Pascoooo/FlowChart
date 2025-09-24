import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';

import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';
import '../../../blocs/project_bloc/project_state.dart';

enum RecoveryAction { recoverAll, discardAll, manualSelect, cancelled }

// --- 3. Widget UI personalizzato ---
class FlowchartPreview extends StatelessWidget {
  final String flowchartContent;
  final bool showUnsavedBadge;

  const FlowchartPreview({
    super.key,
    required this.flowchartContent,
    this.showUnsavedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
        borderRadius: BorderRadius.circular(8),
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          Center(child: Text(flowchartContent)),
          if (showUnsavedBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemOrange.resolveFrom(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'NON SALVATO',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// --- FINE CLASSI SEGNAPOSTO ---


class RecoveryDialogs {
  static Future<RecoveryAction?> showInitialRecoveryDialog({
    required BuildContext context,
    required String projectName,
  }) {
    return showCupertinoDialog<RecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text('Recupero Sessione per "$projectName"'),
          content: const Text(
              "Sono state trovate modifiche non salvate in uno o più file. Come vuoi procedere?"),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(RecoveryAction.recoverAll),
              isDefaultAction: true,
              child: const Text("Recupera tutti"),
            ),
            CupertinoDialogAction(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(RecoveryAction.manualSelect),
              child: const Text("Scegli manualmente"),
            ),
            CupertinoDialogAction(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(RecoveryAction.discardAll),
              isDestructiveAction: true,
              child: const Text("Scarta tutti"),
            ),
          ],
        );
      },
    );
  }

  static Future<bool?> showManualRecoveryDialog({
    required BuildContext context,
    required UnsavedChangesFound state,
  }) {
    // Presuppone che un ProjectBloc sia già fornito nel contesto sopra il punto di chiamata.
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

// --- WIDGET INTERNI PER IL DIALOGO DI RECUPERO ---

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
      if (_remainingFiles.isNotEmpty) {
        _remainingFiles.removeAt(0);
      }
      // Controlla se è vuoto DOPO la rimozione.
      if (_remainingFiles.isEmpty) {
        // Aggiungi un piccolo ritardo per permettere all'animazione di uscita del Dialog di essere più fluida.
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
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
    final title =
        '${widget.state.projectName} - File: "${currentFile.fileName}" ($processedCount/$totalFiles)';

    void onDiscard() {
      context.read<ProjectBloc>().add(DiscardSingleFileChange(
        projectId: widget.state.projectId,
        fileId: currentFile.fileId,
      ));
      _handleDecision();
    }

    void onRecover() {
      context.read<ProjectBloc>().add(RecoverSingleFile(
        projectId: widget.state.projectId,
        fileId: currentFile.fileId,
        rtdbContent: currentFile.rtdbContent,
      ));
      _handleDecision();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      backgroundColor: CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground, context),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _MegaRecoveryDialogLayout(
          key: ValueKey(currentFile.fileId), // La chiave è cruciale per AnimatedSwitcher
          title: title,
          firestoreContent: currentFile.firestoreContent,
          rtdbContent: currentFile.rtdbContent,
          onKeepSaved: onDiscard,
          onRecoverLocal: onRecover,
        ),
      ),
    );
  }
}

class _MegaRecoveryDialogLayout extends StatelessWidget {
  final String title;
  final String firestoreContent;
  final String rtdbContent;
  final VoidCallback onKeepSaved;
  final VoidCallback onRecoverLocal;

  const _MegaRecoveryDialogLayout({
    super.key,
    required this.title,
    required this.firestoreContent,
    required this.rtdbContent,
    required this.onKeepSaved,
    required this.onRecoverLocal,
  });

  @override
  Widget build(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final dialogWidth = MediaQuery.of(context).size.width * 0.85;
    final dialogHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      width: dialogWidth,
      height: dialogHeight,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title,
            style: cupertinoTheme.textTheme.navLargeTitleTextStyle
                .copyWith(fontSize: 24),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            "Scegli quale versione del file desideri conservare.",
            style: cupertinoTheme.textTheme.textStyle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                _buildPreviewColumn(
                  context,
                  title: "Versione Salvata",
                  subtitle: "(Questa versione è al sicuro nel cloud)",
                  content: firestoreContent,
                  showUnsavedBadge: false,
                ),
                const VerticalDivider(width: 32, thickness: 1),
                _buildPreviewColumn(
                  context,
                  title: "Versione NON Salvata",
                  subtitle: "(Da una sessione precedente)",
                  content: rtdbContent,
                  showUnsavedBadge: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: CupertinoButton(
                  onPressed: onKeepSaved,
                  child: const Text("Conserva Versione Salvata"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: onRecoverLocal,
                  child: const Text("Recupera Modifiche"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewColumn(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String content,
        bool showUnsavedBadge = false,
      }) {
    final cupertinoTheme = CupertinoTheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(title, style: cupertinoTheme.textTheme.navTitleTextStyle),
          Text(subtitle,
              style: cupertinoTheme.textTheme.tabLabelTextStyle,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Expanded(
            child: FlowchartPreview(
              flowchartContent: content,
              showUnsavedBadge: showUnsavedBadge,
            ),
          ),
        ],
      ),
    );
  }
}
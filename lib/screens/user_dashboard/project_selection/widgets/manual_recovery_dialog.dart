import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../blocs/project_bloc/project_state.dart';
import 'recovery_dialog.dart';

class ManualRecoveryDialog extends StatefulWidget {
  final UnsavedChangesFound state;
  const ManualRecoveryDialog({super.key, required this.state});

  @override
  State<ManualRecoveryDialog> createState() => _ManualRecoveryDialogState();
}

class _ManualRecoveryDialogState extends State<ManualRecoveryDialog> {
  late List<UnsavedFileChange> _remainingFiles;

  @override
  void initState() {
    super.initState();
    // Creiamo una copia della lista per poterla modificare
    _remainingFiles = List.from(widget.state.changedFiles);
  }

  void _handleDecision() {
    setState(() {
      // Rimuoviamo sempre il primo file dalla lista (quello appena processato)
      _remainingFiles.removeAt(0);

      // Se non ci sono più file, chiudiamo il dialogo e torniamo alla dashboard
      if (_remainingFiles.isEmpty) {
        context.read<ProjectBloc>().add(const LoadProjects());
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se la lista è vuota, significa che abbiamo finito e il dialogo si sta chiudendo
    if (_remainingFiles.isEmpty) {
      return const Material(color: Colors.transparent);
    }

    // Lavoriamo sempre con il primo elemento della lista
    final currentFile = _remainingFiles.first;
    final totalFiles = widget.state.changedFiles.length;
    final processedCount = totalFiles - _remainingFiles.length + 1;

    return RecoveryDialog(
      // Usiamo una Key univoca per forzare Flutter a ridisegnare completamente
      // il dialogo quando passiamo al file successivo, mostrando le nuove anteprime.
      key: ValueKey(currentFile.fileId),

      projectName: '${widget.state.projectName} - File: "${currentFile.fileName}" ($processedCount/$totalFiles)',
      firestoreContent: currentFile.firestoreContent,
      rtdbContent: currentFile.rtdbContent,
      onRecover: () {
        context.read<ProjectBloc>().add(RecoverSingleFile(
          projectId: widget.state.projectId,
          fileId: currentFile.fileId,
          rtdbContent: currentFile.rtdbContent,
        ));
        _handleDecision();
      },
      onDiscard: () {
        context.read<ProjectBloc>().add(DiscardSingleFileChange(
          projectId: widget.state.projectId,
          fileId: currentFile.fileId,
        ));
        _handleDecision();
      },
    );
  }
}
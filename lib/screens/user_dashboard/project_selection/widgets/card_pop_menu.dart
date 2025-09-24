import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../../../../config/services/banner_service.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';
import '../../../../config/services/validation_service.dart';

class CardPopupMenu extends StatelessWidget {
  final MyProject project;
  final List<MyProject> projects;
  final VoidCallback onDeleted;
  final Function(String) onRenamed;

  const CardPopupMenu({
    super.key,
    required this.project,
    required this.projects,
    required this.onDeleted,
    required this.onRenamed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectBloc = context.read<ProjectBloc>();
    final bool isCurrentlyPublic = project.isPublic;

    return PopupMenuButton<String>(
      tooltip: "Opzioni",
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        // --- REFACTOR: Tutte le chiamate ora usano la facciata AppDialogs ---
        if (value == 'rename') {
          final newName = await AppDialogs.showInputDialog(context,
              title: "Rinomina progetto",
              message: "Inserisci un nuovo nome per il progetto",
              initialValue: project.name,
              confirmText: "Rinomina",
              validator: (v) => ValidationService.validateProjectName(v, projects, project.projectId));
          if (newName != null) {
            onRenamed(newName);
          }
        } else if (value == 'delete') {
          final confirm = await AppDialogs.showConfirmationDialog(context,
              title: "Elimina progetto",
              message: "Sei sicuro di voler eliminare '${project.name}'?",
              confirmText: "Elimina",
              isDestructive: true); // --- MODIFICA: Aggiunto flag per azione distruttiva ---
          if (confirm == true) {
            onDeleted();
          }
        } else if (value == 'share') {
          await AppDialogs.showAdvancedShareDialog(
            context: context,
            project: project,
            onMakePublic: () {
              projectBloc.add(UpdateProjectVisibility(
                projectId: project.projectId,
                isPublic: true,
              ));
              BannerService.showSuccess(context, 'Progetto reso pubblico!');
            },
          );
        } else if (value == 'unshare') {
          projectBloc.add(UpdateProjectVisibility(
              projectId: project.projectId, isPublic: false));
          BannerService.showInfo(context, 'Il progetto è di nuovo privato.');
        } else if (value == 'copy_id') {
          await AppDialogs.showShareInfoDialog( // --- MODIFICA: Utilizzo del metodo corretto ---
            context: context,
            title: 'ID Progetto Pubblico',
            message: 'Questo è l\'ID del tuo progetto pubblico. Chiunque lo possegga può visualizzarlo.',
            copyableText: project.projectId,
          );
        }
      },
      // --- ICONOGRAFIA: Tutte le icone sono state sostituite con FontAwesomeIcons ---
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: Row(children: [
            FaIcon(FontAwesomeIcons.penToSquare, size: 16),
            SizedBox(width: 12),
            Text("Rinomina")
          ]),
        ),
        const PopupMenuDivider(),
        if (isCurrentlyPublic) ...[
          PopupMenuItem<String>(
            value: 'copy_id',
            child: Row(children: [
              FaIcon(FontAwesomeIcons.copy, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text("Copia ID Pubblico", style: TextStyle(color: theme.colorScheme.primary)),
            ]),
          ),
          PopupMenuItem<String>(
            value: 'unshare',
            child: Row(children: [
              FaIcon(FontAwesomeIcons.lock, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text("Rendi Privato", style: TextStyle(color: theme.colorScheme.primary)),
            ]),
          ),
        ] else ...[
          PopupMenuItem<String>(
            value: 'share',
            child: Row(children: [
              FaIcon(FontAwesomeIcons.shareNodes, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text("Condividi", style: TextStyle(color: theme.colorScheme.primary)),
            ]),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            FaIcon(FontAwesomeIcons.trashCan, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text("Elimina", style: TextStyle(color: theme.colorScheme.error))
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: FaIcon(FontAwesomeIcons.ellipsisVertical, // Icona aggiornata
            size: 20,
            color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
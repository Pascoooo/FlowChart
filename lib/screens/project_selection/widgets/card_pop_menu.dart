import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';
import '../../../config/services/dialog_service.dart';
import '../widgets/project_container.dart';

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
    return PopupMenuButton<String>(
      tooltip: "Opzioni",
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'rename') {
          final newName = await DialogService.showInputDialog(context,
              title: "Rinomina progetto",
              message: "Inserisci un nuovo nome per il progetto",
              hintText: project.name,
              confirmText: "Rinomina",
              cancelText: "Annulla",
              validator: (v) => ValidationUtils.validateProjectName(v, projects, project.projectId));
          if (newName != null) {
            onRenamed(newName);
          }
        } else if (value == 'delete') {
          final confirm = await DialogService.showConfirmationDialog(context,
              title: "Elimina progetto",
              message: "Sei sicuro di voler eliminare '${project.name}'?",
              confirmText: "Elimina",
              cancelText: "Annulla");
          if (confirm == true) {
            onDeleted();
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text("Rinomina")]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
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
        child: Icon(Icons.more_vert, size: 16, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

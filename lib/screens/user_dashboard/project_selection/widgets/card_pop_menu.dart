/// Contextual popup menu for project card actions.
/// Provides rename, share/visibility toggle, copy public ID, and delete options.
/// Menu adapts based on project's public/private status.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
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

  /// Builds flyout menu button with dynamic items based on project visibility status.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final projectBloc = context.read<ProjectBloc>();
    final bool isCurrentlyPublic = project.isPublic;
    final flyoutController = FlyoutController();
    final outerContext = context;

    return FlyoutTarget(
      controller: flyoutController,
      child: Button(
        style: ButtonStyle(
          backgroundColor:
          ButtonState.all(theme.cardColor.withOpacity(0.8)),
          padding: ButtonState.all(const EdgeInsets.all(4)),
          shape: ButtonState.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        onPressed: () {
          flyoutController.showFlyout(
            builder: (flyoutContext) {
              return MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    onPressed: () async {
                      Navigator.pop(flyoutContext); // Chiude il flyout
                      final newName = await AppDialogs.showInputDialog(
                          outerContext,
                          title: "Rinomina progetto",
                          message: "Inserisci un nuovo nome per il progetto",
                          initialValue: project.name,
                          inputLabel: "Nome Progetto",
                          confirmText: "Rinomina",
                          validator: (v) => ValidationService.validateProjectName(
                              v, projects, project.projectId));
                      if (newName != null) {
                        onRenamed(newName);
                      }
                    },
                    leading: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
                    text: const Text("Rinomina"),
                  ),
                  const MenuFlyoutSeparator(),
                  if (isCurrentlyPublic) ...[
                    MenuFlyoutItem(
                      onPressed: () async {
                        Navigator.pop(flyoutContext);
                        await AppDialogs.showShareInfoDialog(
                          context: outerContext,
                          title: 'ID Progetto Pubblico',
                          message:
                          'Questo è l\'ID del tuo progetto pubblico. Chiunque lo possegga può visualizzarlo.',
                          copyableText: project.projectId,
                        );
                      },
                      leading: FaIcon(FontAwesomeIcons.copy,
                          size: 16, color: theme.accentColor),
                      text: Text("Copia ID Pubblico",
                          style: TextStyle(color: theme.accentColor)),
                    ),
                    MenuFlyoutItem(
                      onPressed: () {
                        Navigator.pop(flyoutContext);
                        projectBloc.add(UpdateProjectVisibility(
                            projectId: project.projectId, isPublic: false));
                        BannerService.showInfo(
                            outerContext, 'Il progetto è di nuovo privato.');
                      },
                      leading: FaIcon(FontAwesomeIcons.lock,
                          size: 16, color: theme.accentColor),
                      text: Text("Rendi Privato",
                          style: TextStyle(color: theme.accentColor)),
                    ),
                  ] else ...[
                    MenuFlyoutItem(
                      onPressed: () async {
                        Navigator.pop(flyoutContext);
                        await AppDialogs.showAdvancedShareDialog(
                          context: outerContext,
                          project: project,
                          onMakePublic: () {
                            projectBloc.add(UpdateProjectVisibility(
                              projectId: project.projectId,
                              isPublic: true,
                            ));
                            BannerService.showSuccess(
                                outerContext, 'Progetto reso pubblico!');
                          },
                        );
                      },
                      leading: FaIcon(FontAwesomeIcons.shareNodes,
                          size: 16, color: theme.accentColor),
                      text: Text("Condividi",
                          style: TextStyle(color: theme.accentColor)),
                    ),
                  ],
                  const MenuFlyoutSeparator(),
                  MenuFlyoutItem(
                    onPressed: () async {
                      Navigator.pop(flyoutContext);
                      final confirm = await AppDialogs.showConfirmationDialog(
                          outerContext,
                          title: "Elimina progetto",
                          message:
                          "Sei sicuro di voler eliminare '${project.name}'?",
                          confirmText: "Elimina",
                          isDestructive: true);
                      if (confirm == true) {
                        onDeleted();
                      }
                    },
                    leading: FaIcon(FontAwesomeIcons.trashCan,
                        size: 16, color: Colors.red),
                    text: Text("Elimina", style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        },
        child: FaIcon(FontAwesomeIcons.ellipsisVertical,
            size: 20, color: theme.typography.body?.color?.withOpacity(0.8)),
      ),
    );
  }
}

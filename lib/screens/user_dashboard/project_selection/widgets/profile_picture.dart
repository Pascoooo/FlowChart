import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../../blocs/auth_bloc/authentication_event.dart';
import '../../../../config/router/app_router.dart';
import '../../../../config/services/dialog_service/app_dialogs.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final user = context.watch<AuthenticationBloc>().state.user;
    final flyoutController = FlyoutController();
    final outerContext = context;

    return FlyoutTarget(
      controller: flyoutController,
      child: GestureDetector
        (
        onTap: () {
          flyoutController.showFlyout(
            placementMode: FlyoutPlacementMode.bottomRight,
            builder: (flyoutContext) {
              return MenuFlyout(
                items: [
                  MenuFlyoutItem(
                    onPressed: () {
                      Navigator.pop(flyoutContext);
                      AppRouter.goToSettings(outerContext);
                    },
                    leading: Icon(FontAwesomeIcons.gear,
                        size: 16,
                        color: theme.typography.body?.color?.withOpacity(0.8)),
                    text: const Text("Impostazioni"),
                  ),
                  MenuFlyoutItem(
                    onPressed: () async {
                      Navigator.pop(flyoutContext);
                      final confirm = await AppDialogs.showConfirmationDialog(
                          outerContext,
                          title: "Logout",
                          isDestructive: true,
                          message: "Sei sicuro di voler uscire?",
                          confirmText: "Esci",
                          cancelText: "Annulla");
                      if (confirm == true) {
                        outerContext
                            .read<AuthenticationBloc>()
                            .add(const AuthenticationLogoutRequested());
                      }
                    },
                    leading: Icon(FontAwesomeIcons.rightFromBracket,
                        size: 16, color: Colors.red),
                    text: Text("Logout", style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        },
        child: Hero(
          tag: 'profilePicture',
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 3))
              ],
            ),
            child: ClipOval(
              child: user.photoURL.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: user.photoURL,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                    child: ProgressRing(
                        activeColor: theme.accentColor,
                        strokeWidth: 2)),
                errorWidget: (context, url, error) =>
                    Icon(FontAwesomeIcons.circleExclamation,
                        size: 24, color: theme.typography.body?.color
              ),
              )
                  : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.inactiveColor.withOpacity(0.2)),
                child: Icon(FontAwesomeIcons.user,
                    size: 24, color: theme.typography.body?.color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

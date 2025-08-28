import 'package:flowchart_thesis/config/widgets/buttons.dart';
import 'package:flutter/material.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import 'dart:js' as js;

class TopbarButtons extends StatelessWidget {
  final FileSystemState state;

  const TopbarButtons({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String currentPage = "Dashboard";

    if (state is FileSystemLoaded &&
        (state as FileSystemLoaded).activeFileId != null &&
        (state as FileSystemLoaded).files.isNotEmpty) {
      final loadedState = state as FileSystemLoaded;
      final matchingFiles =
          loadedState.files.where((f) => f.fileId == loadedState.activeFileId);
      if (matchingFiles.isNotEmpty) {
        currentPage = matchingFiles.first.name;
      }
    }

    final titleStyle = theme.textTheme.titleMedium ?? const TextStyle();
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Unichart",
          style: titleStyle.copyWith(
            color: onSurfaceColor.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right,
          size: 12,
          color: onSurfaceColor.withOpacity(0.4),
        ),
        const SizedBox(width: 8),
        Text(
          currentPage,
          style: titleStyle.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        ModernMenuItem(
          icon: Icons.edit,
          title: "Modifica",
          isPrimaryAction: true,
          onTap: () {
            final baseUrl = Uri.base.toString().split('#')[0];
            js.context.callMethod('open', [
              '$baseUrl#/drawing-editor',
              '_blank',
              'width=1200,height=800,left=100,top=100,resizable=yes,scrollbars=yes,status=yes'
            ]);
          },
        ),
      ],
    );
  }
}

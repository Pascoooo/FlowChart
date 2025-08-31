// lib/screens/user_dashboard/widgets/topbar_buttons.dart (Updated)
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../config/widgets/buttons.dart';

class TopbarButtons extends StatelessWidget {
  final FileSystemLoaded state;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const TopbarButtons({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelectedFile = state.activeFileId != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSelectedFile) ...[
          ModernMenuItem(
            icon: FontAwesomeIcons.penToSquare,
            onTap: onEdit,
            isPrimaryAction: true,
            title: 'Modifica',
          ),
          const SizedBox(width: 8),
          ModernMenuItem(
            icon: FontAwesomeIcons.download,
            onTap: onExport,
            title: 'Esporta',
          ),
        ],
      ],
    );
  }
}
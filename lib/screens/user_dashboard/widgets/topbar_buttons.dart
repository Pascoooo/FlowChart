// lib/screens/user_dashboard/widgets/topbar_buttons.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../blocs/flowchart_bloc/flowchart_state.dart';
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

  void _addShape(BuildContext context, String type) {
    final shape = FlowchartShape(
      id: UniqueKey().toString(),
      type: type,
      x: 100,
      y: 100,
      properties: {},
    );
    context.read<FlowchartBloc>().add(AddShape(shape));
  }

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
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

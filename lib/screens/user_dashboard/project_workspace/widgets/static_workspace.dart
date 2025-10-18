// lib/screens/user_dashboard/project_workspace/widgets/static_workspace.dart

import 'package:file_repository/file_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:project_repository/project_repository.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../views/workarea.dart';

class StaticProjectWorkspace extends StatefulWidget {
  final MyProject project;
  final List<MyFile> files;

  const StaticProjectWorkspace({
    super.key,
    required this.project,
    required this.files,
  });

  @override
  State<StaticProjectWorkspace> createState() => _StaticProjectWorkspaceState();
}

class _StaticProjectWorkspaceState extends State<StaticProjectWorkspace> {
  String? _activeFileId;

  @override
  void initState() {
    super.initState();
    if (widget.files.isNotEmpty) {
      final mainFile = widget.files.firstWhere(
            (file) => file.name == 'main',
        orElse: () => widget.files.first,
      );
      _activeFileId = mainFile.fileId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFile = widget.files.firstWhere(
          (file) => file.fileId == _activeFileId,
      orElse: () => widget.files.isNotEmpty ? widget.files.first : MyFile.empty,
    );

    return BlocProvider<FlowchartBloc>(
      key: ValueKey(_activeFileId),
      create: (context) => FlowchartBloc()
        ..add(LoadFlowchart(
          jsonContent: activeFile.content,
          fileName: activeFile.name,
          fileId: activeFile.fileId,
        )),
      child: Row(
        children: [
          _StaticSidebar(
            files: widget.files,
            activeFileId: _activeFileId,
            onFileSelected: (fileId) {
              setState(() {
                _activeFileId = fileId;
              });
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _StaticTopBar(
                    projectName: widget.project.name,
                    fileName: activeFile.name,
                  ),
                  const SizedBox(height: 16),
                  Expanded( // FIX: Rimosso 'const' da qui
                    child: WorkArea(
                      repaintKey: GlobalKey(),
                      showGrid: true,
                      isReadOnly: true,
                      allowDragInReadOnly: true,
                      onToggleGrid: () {}, // FIX: Sostituito null con una funzione vuota
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticSidebar extends StatelessWidget {
  final List<MyFile> files;
  final String? activeFileId;
  final ValueChanged<String> onFileSelected;

  const _StaticSidebar({
    required this.files,
    required this.activeFileId,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () =>
              context.read<ProjectBloc>().add(const LeaveProject()),
            ),
            title: Text('Progetto Condiviso', style: theme.typography.bodyStrong),
          ),
          const Divider(
            style: DividerThemeData(
              horizontalMargin: EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isSelected = file.fileId == activeFileId;
                return ListTile(
                  leading: Icon(
                    FontAwesomeIcons.fileCode,
                    // FIX: Sostituito disabledColor con inactiveColor
                    color: isSelected ? theme.accentColor : theme.inactiveColor,
                  ),
                  title: Text(
                    file.name,
                    style: (theme.typography.body ?? const TextStyle()).copyWith(
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.accentColor : null,
                    ),
                  ),
                  onPressed: () => onFileSelected(file.fileId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticTopBar extends StatelessWidget {
  final String projectName;
  final String fileName;

  const _StaticTopBar({required this.projectName, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.inactiveColor.withValues(alpha: 0.1)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(FontAwesomeIcons.diagramProject, color: theme.accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  projectName,
                  style: theme.typography.bodyStrong,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Visualizzando: $fileName (sola lettura)',
                  style: theme.typography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
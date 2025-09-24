import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';
import 'package:file_repository/file_repository.dart';

import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import '../views/workarea.dart'; // Riutilizziamo la WorkArea per la visualizzazione

/// Un workspace semplificato e statico per la visualizzazione di progetti condivisi.
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
  // Lo stato locale di questo widget terrà traccia solo del file attivo
  String? _activeFileId;

  @override
  void initState() {
    super.initState();
    // All'avvio, se ci sono file, seleziona il primo come attivo
    if (widget.files.isNotEmpty) {
      _activeFileId = widget.files.first.fileId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Troviamo il file attualmente selezionato
    final activeFile = widget.files.firstWhere(
          (file) => file.fileId == _activeFileId,
      orElse: () => MyFile.empty, // Un file vuoto se non ne trova
    );

    return MultiBlocProvider(
      providers: [
        // Forniamo un FlowchartBloc locale solo per questo workspace statico.
        // La sua unica responsabilità è caricare e mostrare il contenuto del file.
        BlocProvider<FlowchartBloc>(
          // Usiamo una key per forzare la ricreazione del BLoC se il file cambia
          key: ValueKey(_activeFileId),
          create: (context) => FlowchartBloc()
            ..add(LoadFlowchart(
              jsonContent: activeFile.content,
              fileName: activeFile.name,
            )),
        ),
      ],
      child: Row(
        children: [
          // 1. Una Sidebar semplificata, senza "Nuovo File"
          _StaticSidebar(
            files: widget.files,
            activeFileId: _activeFileId,
            onFileSelected: (fileId) {
              setState(() {
                _activeFileId = fileId;
              });
            },
          ),
          // 2. L'area di lavoro principale
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 3. Una TopBar semplificata, senza bottoni di modifica
                  _StaticTopBar(
                    projectName: widget.project.name,
                    fileName: activeFile.name,
                  ),
                  const SizedBox(height: 16),
                  // 4. L'area di disegno, che ora mostrerà il flowchart statico
                  Expanded(
                    child: WorkArea(
                      repaintKey: GlobalKey(), // Una nuova chiave per la vista statica
                      showGrid: true,
                      isReadOnly: true, // Impostiamo la modalità sola lettura
                      onToggleGrid: () {}, // La griglia è sempre attiva e non modificabile
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

// --- WIDGET INTERNI E SEMPLIFICATI PER LA VISTA STATICA ---

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
    final theme = Theme.of(context);
    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header con pulsante per tornare indietro
          ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.read<ProjectBloc>().add(const LeaveProject()),
            ),
            title: Text('Progetto Condiviso', style: theme.textTheme.titleMedium),
          ),
          const Divider(indent: 16, endIndent: 16),
          // Lista dei file
          Expanded(
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isSelected = file.fileId == activeFileId;
                return ListTile(
                  leading: Icon(
                    Icons.insert_drive_file,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    file.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  onTap: () => onFileSelected(file.fileId),
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
    final theme = Theme.of(context);
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.visibility, color: theme.colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  projectName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Visualizzando: $fileName (sola lettura)',
                  style: theme.textTheme.bodySmall,
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
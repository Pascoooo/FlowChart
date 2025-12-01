import 'package:file_repository/file_repository.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart' show Navigator;
import 'package:project_repository/project_repository.dart';

import '../../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../../blocs/file_bloc/file_system_state.dart';
import '../../../../blocs/project_bloc/project_bloc.dart';
import '../../../../blocs/project_bloc/project_event.dart';
import 'project_workspace.dart';

/// Workspace per PROGETTO CONDIVISO.
/// Invece di avere una debug mode separata, inizializza il FileSystemBloc con i file condivisi
/// e poi riusa direttamente [ProjectWorkspace] in modalità sola lettura.
/// In questo modo la DebugModeView, la console, la tabella variabili e il call stack
/// sono IDENTICI a quelli del workspace normale.
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
  @override
  void initState() {
    super.initState();
    // Nessuna logica speciale qui: l'inizializzazione avviene nel BlocProvider di FileSystemBloc
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // ProjectBloc esiste già a livello superiore nell'app.
        // Lo usiamo senza modificare lo stato (già in StaticWorkspaceLoaded)
        BlocProvider<ProjectBloc>.value(
          value: context.read<ProjectBloc>(),
        ),

        // FileSystemBloc inizializzato direttamente dai file condivisi.
        // Non fa chiamate a Firestore: parte già in stato FileSystemLoaded.
        BlocProvider<FileSystemBloc>(
          create: (ctx) {
            final bloc = FileSystemBloc(
              projectRepository: ctx.read<ProjectBloc>().projectRepository,
            );

            // Costruisci lo stato FileSystemLoaded a partire dai MyFile condivisi
            final files = widget.files;
            String? activeId;
            if (files.isNotEmpty) {
              // Usa 'main' come file attivo se presente, altrimenti il primo
              final mainFile = files.firstWhere(
                (f) => f.name.toLowerCase() == 'main',
                orElse: () => files.first,
              );
              activeId = mainFile.fileId;
            }

            bloc.emit(FileSystemLoaded(
              files: files,
              activeFileId: activeId,
            ));

            return bloc;
          },
        ),
      ],
      child: ProjectWorkspace(
        selectedProject: widget.project,
        isReadOnly: true,
        onLeave: () {
          // In modalità statica NON chiamiamo LeaveProject del ProjectBloc,
          // così non torni forzatamente alla pagina dei progetti.
          // Se la StaticWorkspace è aperta come nuova route, puoi usare:
          // Navigator.of(context).maybePop();
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_repository/project_repository.dart';

import '../../../blocs/project_bloc/project_bloc.dart';
import '../../../blocs/project_bloc/project_event.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selectedProject,
  });
  final MyProject selectedProject;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              selectedProject.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Torna ai progetti'),
            onTap: () {
              // Emette l'evento per tornare indietro
              context.read<ProjectBloc>().add(const DeselectProject());
            },
          ),
          // Aggiungi qui altri elementi della sidebar
        ],
      ),
    );
  }
}
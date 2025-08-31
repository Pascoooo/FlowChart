import 'package:flowchart_thesis/screens/user_dashboard/views/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:project_repository/project_repository.dart';

class Workspace extends StatelessWidget {
  const Workspace({
    super.key,
    required this.selectedProject,
  });

  final MyProject selectedProject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(selectedProject.name),
        // Rimuovi questo parametro o impostalo su true.
        // automaticallyImplyLeading: false,
      ),
      // Usa la nuova sidebar
      drawer: Sidebar(selectedProject: selectedProject),
      body: Center(
        child: Text('Workspace for ${selectedProject.name}'),
      ),
    );
  }
}
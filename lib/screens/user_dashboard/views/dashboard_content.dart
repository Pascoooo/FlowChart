import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_state.dart';
import '../error/error_view.dart';
import '../widgets/topbar.dart';
import 'project_view.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        return Column(
          children: [
            TopBar(state: state as FileSystemLoaded),
            Expanded(
              child: _buildContent(state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(FileSystemState state) {
    if (state is FileSystemLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is FileSystemError) {
      return ErrorView(message: state.message);
    }
    if (state is FileSystemLoaded) {
      if (state.activeFileId != null) {
        return ProjectView(state: state);
      } else {
        return const Center(
          child: Text("Nessun progetto aperto"),
        );
      }
    }
    return const Center(child: Text("Stato sconosciuto"));
  }
}
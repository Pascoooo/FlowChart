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
    return Column(
      children: [
        const TopBar(),
        Expanded(
          child: BlocBuilder<FileSystemBloc, FileSystemState>(
            builder: (context, state) {
              if (state is FileSystemLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is FileSystemError) {
                return ErrorView(message: state.message);
              }
              if (state is FileSystemLoaded) {
                if (state.activeFileId != null) {
                  return ProjectView(state: state, editingMode: false);
                } else {
                  return ProjectView(state: state, editingMode: true);
                }
              }
              return const Center(child: Text('Unknown state', style: TextStyle(color: Colors.red)));
            },
          ),
        ),
      ],
    );
  }
}
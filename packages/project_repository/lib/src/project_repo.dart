import 'package:file_repository/file_repository.dart';
import '../project_repository.dart';

abstract class ProjectRepo {
  /// Project-level methods
  Future<List<MyProject>> getProjects();
  Future<void> createProject({required String name});
  Future<void> deleteProject({required String projectId});
  Future<void> renameProject({required String projectId, required String newName});


  /// File-level methods, scoped to a project
  Future<List<MyFile>> getProjectFiles({required String projectId});
  Future<void> addFileToProject({required String projectId, required String fileName, required String content});
  Future<void> deleteFile({required String projectId, required String fileId});
  Future<void> renameFile({required String projectId, required String fileId, required String newName});
  Future<void> updateFileContent({required String projectId, required String fileId, required String newContent});
}
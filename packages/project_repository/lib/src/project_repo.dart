import 'package:file_repository/file_repository.dart';
import '../project_repository.dart';

abstract class ProjectRepo {
  Stream<List<MyProject>> projects();

  Future<MyProject> createProject({required String name});
  Future<void> deleteProject({required String projectId});
  Future<void> renameProject({required String projectId, required String newName});

  Future<Map<String, DateTime>> getUserTimestamps();
  Future<void> saveUserTimestamps(Map<String, DateTime> timestamps);

  Future<List<MyFile>> getProjectFiles({required String projectId});
  Future<void> addFileToProject({required String projectId, required String fileName, required String content});
  Future<void> deleteFile({required String projectId, required String fileId});
  Future<void> renameFile({required String projectId, required String fileId, required String newName});
  Future<void> updateFileContent({required String projectId, required String fileId, required String newContent});
}
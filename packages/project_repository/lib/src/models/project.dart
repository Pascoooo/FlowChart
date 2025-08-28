import '../entities/project_entity.dart';

class MyProject {
  final String projectId;
  final String name;

  const MyProject({
    required this.projectId,
    required this.name,
  });

  // Converte un oggetto MyProject in un'entità.
  MyProjectEntity toEntity() {
    return MyProjectEntity(
      projectId: projectId,
      name: name,
    );
  }

  // Crea un oggetto MyProject da un'entità.
  static MyProject fromEntity(MyProjectEntity entity) {
    return MyProject(
      projectId: entity.projectId,
      name: entity.name,
    );
  }
}
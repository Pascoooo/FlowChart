import '../entities/project_entity.dart';

class MyProject {
  final String projectId;
  final String name;
  final DateTime updatedAt;

   const MyProject({
    required this.projectId,
    required this.name,
    required this.updatedAt,
  });

  // Converte un oggetto MyProject in un'entità.
  MyProjectEntity toEntity() {
    return MyProjectEntity(
      projectId: projectId,
      name: name,
      updatedAt: updatedAt,
    );
  }

  // Crea un oggetto MyProject da un'entità.
  static MyProject fromEntity(MyProjectEntity entity) {
    return MyProject(
      projectId: entity.projectId,
      name: entity.name,
      updatedAt: entity.updatedAt,
    );
  }

  /// Crea una copia dell'oggetto MyProject, aggiornando solo i campi forniti.
  MyProject copyWith({
    String? name,
    DateTime? updatedAt,
  }) {
    return MyProject(
      projectId: projectId, // L'ID non cambia mai
      name: name ?? this.name, // Usa il nuovo nome se fornito, altrimenti il vecchio
      updatedAt: updatedAt ?? this.updatedAt, // Usa la nuova data se fornita, altrimenti la vecchia
    );
  }
}
class MyProjectEntity {
  String projectId;
  String name;

  MyProjectEntity({
    required this.projectId,
    required this.name,
  });

  // Crea un'entità da un documento Firestore (Map).
  static MyProjectEntity fromDocument(Map<String, dynamic> json) {
    return MyProjectEntity(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
    );
  }

  // Converte l'entità in un documento Firestore (Map).
  Map<String, dynamic> toDocument() {
    return {
      'projectId': projectId,
      'name': name,
    };
  }
}
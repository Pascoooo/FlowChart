class MyFileEntity {
  String fileId;
  String name;
  String content;

  MyFileEntity({
    required this.fileId,
    required this.name,
    required this.content,
  });

  // Crea un'entità da un documento Firestore (Map).
  static MyFileEntity fromDocument(Map<String, dynamic> json) {
    return MyFileEntity(
      fileId: json['fileId'] as String,
      name: json['name'] as String,
      content: json['content'] as String,
    );
  }

  // Converte l'entità in un documento Firestore (Map).
  Map<String, dynamic> toDocument() {
    return {
      'fileId': fileId,
      'name': name,
      'content': content,
    };
  }
}

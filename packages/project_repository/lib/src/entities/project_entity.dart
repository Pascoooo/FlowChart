import 'package:cloud_firestore/cloud_firestore.dart';

class MyProjectEntity {
  String projectId;
  String name;
  DateTime updatedAt;

   MyProjectEntity({
    required this.projectId,
    required this.name,
    required this.updatedAt,
  });

  // Crea un'entità da un documento Firestore (Map).
  static MyProjectEntity fromDocument(Map<String, dynamic> json) {
    return MyProjectEntity(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Converte l'entità in un documento Firestore (Map).
  Map<String, dynamic> toDocument() {
    return {
      'projectId': projectId,
      'name': name,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
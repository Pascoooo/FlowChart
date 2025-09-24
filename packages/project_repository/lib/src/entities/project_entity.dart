// lib/entities/my_project_entity.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class MyProjectEntity {
  String projectId;
  String name;
  DateTime updatedAt;
  bool isPublic;
  String ownerId;
  DateTime? lastVisibilityChange;

  MyProjectEntity({
    required this.projectId,
    required this.name,
    required this.updatedAt,
    required this.ownerId,
    this.lastVisibilityChange,
    this.isPublic = false,
  });

  // --- MODIFICA FONDAMENTALE QUI ---
  static MyProjectEntity fromDocument(Map<String, dynamic> json) {
    final updatedAtTs = json['updatedAt'] as Timestamp;
    final lastChangeTs = json['lastVisibilityChange'] as Timestamp?; // Legge il timestamp (che può essere nullo)

    return MyProjectEntity(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      updatedAt: updatedAtTs.toDate(),
      isPublic: json['isPublic'] as bool? ?? false,
      ownerId: json['ownerId'] as String,
      lastVisibilityChange: lastChangeTs?.toDate(),
    );
  }

  // Il resto del file (toDocument) è corretto e non va toccato.
  Map<String, dynamic> toDocument() {
    return {
      'projectId': projectId,
      'name': name,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPublic': isPublic,
      'ownerId': ownerId,
      if (lastVisibilityChange != null)
        'lastVisibilityChange': Timestamp.fromDate(lastVisibilityChange!),
    };
  }
}
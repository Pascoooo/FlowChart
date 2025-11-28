// lib/entities/my_project_entity.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Entity che rappresenta i dati di un progetto nel formato Firestore.
/// Utilizzata per serializzare/deserializzare documenti dalla collection 'projects'.
/// Separa il livello di persistenza dal modello di dominio (MyProject).
class MyProjectEntity {
  final String projectId;
  final String name;
  final DateTime updatedAt;
  final bool isPublic;
  final String ownerId;
  final DateTime? lastVisibilityChange;

  MyProjectEntity({
    required this.projectId,
    required this.name,
    required this.updatedAt,
    required this.ownerId,
    this.lastVisibilityChange,
    this.isPublic = false,
  });

  /// Crea un'istanza di MyProjectEntity da un documento Firestore.
  /// Converte i Timestamp in DateTime e gestisce i campi opzionali.
  static MyProjectEntity fromDocument(Map<String, dynamic> json) {
    final updatedAtTs = json['updatedAt'] as Timestamp;
    final lastChangeTs = json['lastVisibilityChange'] as Timestamp?;

    return MyProjectEntity(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      updatedAt: updatedAtTs.toDate(),
      isPublic: json['isPublic'] as bool? ?? false,
      ownerId: json['ownerId'] as String,
      lastVisibilityChange: lastChangeTs?.toDate(),
    );
  }

  /// Converte MyProjectEntity in una mappa per la scrittura su Firestore.
  /// Serializza le date in Timestamp e omette campi null opzionali.
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
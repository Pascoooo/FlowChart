// lib/models/my_project.dart

import '../entities/project_entity.dart';

/// Rappresenta un progetto utente contenente flowchart e file.
/// Include metadati come nome, data ultimo aggiornamento, visibilità pubblica
/// e gestione del rate limiting per le modifiche di visibilità.
class MyProject {
  final String projectId;
  final String name;
  final DateTime updatedAt;
  final bool isPublic;
  final String ownerId;
  final DateTime? lastVisibilityChange;

  const MyProject({
    required this.projectId,
    required this.name,
    required this.updatedAt,
    this.isPublic = false,
    this.ownerId = '',
    this.lastVisibilityChange,
  });

  /// Converte MyProject in MyProjectEntity per la persistenza su Firestore.
  /// Se lastVisibilityChange è null, usa updatedAt come fallback.
  MyProjectEntity toEntity() {
    return MyProjectEntity(
      projectId: projectId,
      name: name,
      updatedAt: updatedAt,
      isPublic: isPublic,
      ownerId: ownerId,
      lastVisibilityChange: lastVisibilityChange ?? updatedAt,
    );
  }

  /// Crea un'istanza di MyProject da MyProjectEntity (deserializzazione).
  /// Utilizzato per convertire i dati dal database nel modello di dominio.
  static MyProject fromEntity(MyProjectEntity entity) {
    return MyProject(
      projectId: entity.projectId,
      name: entity.name,
      updatedAt: entity.updatedAt,
      isPublic: entity.isPublic,
      ownerId: entity.ownerId,
      lastVisibilityChange: entity.lastVisibilityChange,
    );
  }

  /// Crea una copia di MyProject con i campi specificati aggiornati.
  /// Il projectId non può essere modificato. Tutti gli altri parametri sono opzionali.
  MyProject copyWith({
    String? name,
    DateTime? updatedAt,
    bool? isPublic,
    String? ownerId,
    DateTime? lastVisibilityChange,
  }) {
    return MyProject(
      projectId: projectId,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      ownerId: ownerId ?? this.ownerId,
      lastVisibilityChange: lastVisibilityChange ?? this.lastVisibilityChange,
    );
  }
}
// lib/models/my_project.dart

import '../entities/project_entity.dart';

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
    this.lastVisibilityChange, // Non più 'required'
  });

  MyProjectEntity toEntity() {
    return MyProjectEntity(
      projectId: projectId,
      name: name,
      updatedAt: updatedAt,
      isPublic: isPublic,
      ownerId: ownerId,
      // Se è null (improbabile in scrittura), usa updatedAt come fallback
      lastVisibilityChange: lastVisibilityChange ?? updatedAt,
    );
  }

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
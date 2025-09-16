import 'package:cloud_firestore/cloud_firestore.dart';

class MyUserEntity {
  final String userId;
  final String email;
  final String name;
  final String photoURL;
  final Timestamp? nameLastUpdatedAt;
  final Timestamp? photoLastUpdatedAt;
  final bool driveConnected;

  const MyUserEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
    this.nameLastUpdatedAt,
    this.photoLastUpdatedAt,
    this.driveConnected = false,
  });

  static MyUserEntity fromDocument(Map<String, dynamic> doc) {
    return MyUserEntity(
      userId: doc['userId'] as String,
      email: doc['email'] as String,
      name: doc['name'] as String,
      photoURL: doc['photoURL'] as String,
      nameLastUpdatedAt: doc['nameLastUpdatedAt'] as Timestamp?,
      photoLastUpdatedAt: doc['photoLastUpdatedAt'] as Timestamp?,
      driveConnected: doc['driveConnected'] as bool? ?? false,
    );
  }

  Map<String, Object?> toDocument() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'photoURL': photoURL,
      'nameLastUpdatedAt': nameLastUpdatedAt,
      'photoLastUpdatedAt': photoLastUpdatedAt,
      'driveConnected': driveConnected,
    };
  }
}
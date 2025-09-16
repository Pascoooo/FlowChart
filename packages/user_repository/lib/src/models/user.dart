import '../entities/entities.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyUser extends Equatable {
  final String userId;
  final String email;
  final String name;
  final String photoURL;
  final Timestamp? nameLastUpdatedAt;
  final Timestamp? photoLastUpdatedAt;
  final bool driveConnected; // NUOVO CAMPO

  const MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
    this.nameLastUpdatedAt,
    this.photoLastUpdatedAt,
    this.driveConnected = false, // VALORE DI DEFAULT
  });

  static const empty = MyUser(
    userId: '',
    email: '',
    name: '',
    photoURL: '',
    driveConnected: false, // AGGIUNTO QUI
  );

  bool get isEmpty => this == MyUser.empty;

  MyUser copyWith({
    String? userId,
    String? email,
    String? name,
    String? photoURL,
    Timestamp? nameLastUpdatedAt,
    Timestamp? photoLastUpdatedAt,
    bool? driveConnected, // AGGIUNTO QUI
  }) {
    return MyUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      photoURL: photoURL ?? this.photoURL,
      nameLastUpdatedAt: nameLastUpdatedAt ?? this.nameLastUpdatedAt,
      photoLastUpdatedAt: photoLastUpdatedAt ?? this.photoLastUpdatedAt,
      driveConnected: driveConnected ?? this.driveConnected, // AGGIUNTO QUI
    );
  }

  MyUserEntity toEntity() {
    return MyUserEntity(
      userId: userId,
      email: email,
      name: name,
      photoURL: photoURL,
      nameLastUpdatedAt: nameLastUpdatedAt,
      photoLastUpdatedAt: photoLastUpdatedAt,
      driveConnected: driveConnected, // AGGIUNTO QUI
    );
  }

  static MyUser fromEntity(MyUserEntity entity) {
    return MyUser(
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      photoURL: entity.photoURL,
      nameLastUpdatedAt: entity.nameLastUpdatedAt,
      photoLastUpdatedAt: entity.photoLastUpdatedAt,
      driveConnected: entity.driveConnected, // AGGIUNTO QUI
    );
  }

  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    photoURL,
    nameLastUpdatedAt,
    photoLastUpdatedAt,
    driveConnected, // AGGIUNTO QUI
  ];
}
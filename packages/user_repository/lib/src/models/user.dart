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

  const MyUser({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
    this.nameLastUpdatedAt,
    this.photoLastUpdatedAt,
  });

  /// Utente vuoto per stati iniziali o di logout.
  static const empty = MyUser(
    userId: '',
    email: '',
    name: '',
    photoURL: '',
    nameLastUpdatedAt: null,
    photoLastUpdatedAt: null,
  );

  /// Getter per controllare se l'utente è vuoto.
  bool get isEmpty => this == MyUser.empty;

  /// Crea una copia dell'utente con valori aggiornati.
  MyUser copyWith({
    String? userId,
    String? email,
    String? name,
    String? photoURL,
    Timestamp? nameLastUpdatedAt,
    Timestamp? photoLastUpdatedAt,
  }) {
    return MyUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      photoURL: photoURL ?? this.photoURL,
      nameLastUpdatedAt: nameLastUpdatedAt ?? this.nameLastUpdatedAt,
      photoLastUpdatedAt: photoLastUpdatedAt ?? this.photoLastUpdatedAt,
    );
  }

  /// Converte il modello di dominio in un'entità dati.
  MyUserEntity toEntity() {
    return MyUserEntity(
      userId: userId,
      email: email,
      name: name,
      photoURL: photoURL,
      nameLastUpdatedAt: nameLastUpdatedAt,
      photoLastUpdatedAt: photoLastUpdatedAt,
    );
  }

  /// Crea un modello di dominio da un'entità dati.
  static MyUser fromEntity(MyUserEntity entity) {
    return MyUser(
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      photoURL: entity.photoURL,
      nameLastUpdatedAt: entity.nameLastUpdatedAt,
      photoLastUpdatedAt: entity.photoLastUpdatedAt,
    );
  }

  @override
  String toString() {
    return 'MyUser: $userId, $name';
  }


  @override
  List<Object?> get props => [
    userId,
    email,
    name,
    photoURL,
    nameLastUpdatedAt,
    photoLastUpdatedAt,
  ];
}
import '../entities/entities.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Rappresenta un utente dell'applicazione con profilo e impostazioni.
/// Include dati di autenticazione e informazioni di profilo (nome, foto).
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

  static const empty = MyUser(
    userId: '',
    email: '',
    name: '',
    photoURL: '',
  );

  bool get isEmpty => this == MyUser.empty;

  /// Crea una copia di MyUser con i campi specificati aggiornati.
  /// Tutti i parametri sono opzionali; i campi non specificati mantengono
  /// il valore corrente.
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

  /// Converte il modello MyUser in MyUserEntity per la persistenza.
  /// MyUserEntity viene usato per serializzare i dati verso Firestore.
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

  /// Converte MyUserEntity (dal database) in un'istanza di MyUser.
  /// Utilizzato per deserializzare i dati ricevuti da Firestore nel modello di dominio.
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
  List<Object?> get props => [
    userId,
    email,
    name,
    photoURL,
    nameLastUpdatedAt,
    photoLastUpdatedAt,
  ];
}

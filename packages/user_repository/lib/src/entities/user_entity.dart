import 'package:cloud_firestore/cloud_firestore.dart';

/// Entity che rappresenta i dati utente nel formato Firestore.
/// Utilizzata per serializzare/deserializzare documenti dalla collection 'users'.
/// Questa classe separa il livello di persistenza dal modello di dominio (MyUser).
class MyUserEntity {
  final String userId;
  final String email;
  final String name;
  final String photoURL;
  final Timestamp? nameLastUpdatedAt;
  final Timestamp? photoLastUpdatedAt;

  const MyUserEntity({
    required this.userId,
    required this.email,
    required this.name,
    required this.photoURL,
    this.nameLastUpdatedAt,
    this.photoLastUpdatedAt,
  });

  /// Crea un'istanza di MyUserEntity da un documento Firestore.
  /// Converte i dati grezzi dal database nel formato entity, gestendo
  /// i cast e i valori di default per campi opzionali.
  static MyUserEntity fromDocument(Map<String, dynamic> doc) {
    return MyUserEntity(
      userId: doc['userId'] as String,
      email: doc['email'] as String,
      name: doc['name'] as String,
      photoURL: doc['photoURL'] as String,
      nameLastUpdatedAt: doc['nameLastUpdatedAt'] as Timestamp?,
      photoLastUpdatedAt: doc['photoLastUpdatedAt'] as Timestamp?,
    );
  }

  /// Converte MyUserEntity in una mappa per la scrittura su Firestore.
  /// Tutti i campi vengono serializzati nel formato compatibile con
  /// il database (Timestamp, primitive types).
  Map<String, Object?> toDocument() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'photoURL': photoURL,
      'nameLastUpdatedAt': nameLastUpdatedAt,
      'photoLastUpdatedAt': photoLastUpdatedAt,
    };
  }
}

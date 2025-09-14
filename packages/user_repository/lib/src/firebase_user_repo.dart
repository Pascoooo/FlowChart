// firebase_user_repo.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../user_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

const String kFunctionsRegion = 'europe-west8';
// Potresti definire le costanti in un file separato
const String kDeleteUserFunctionName = 'deleteUserAuthHttp';
const Duration kApiTimeoutDuration = Duration(seconds: 15);

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseDatabase _rtdb;
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseDatabase? rtdb,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _rtdb = rtdb ?? FirebaseDatabase.instance {
    _usersCollection = _firestore.collection('users');
  }

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(null);
      } else {
        return _usersCollection
            .doc(firebaseUser.uid)
            .snapshots()
            .map((snapshot) => snapshot.exists
            ? MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!))
            : null);
      }
    }).distinct();
  }

  Future<MyUser> _createUserFromFirebase(User firebaseUser) async {
    final newUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );
    await setUserData(newUser);
    return newUser;
  }

  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await _usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }
  // firebase_user_repo.dart

  @override
  Future<void> updateUserDisplayName(String displayName) async {
    if (displayName.trim().isEmpty) {
      throw const AuthenticationException("Il nome visualizzato non può essere vuoto.");
    }

    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthenticationException("Utente non autenticato.");
    }

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        throw const AuthenticationException("Documento utente non trovato.");
      }

      // --- NUOVA LOGICA DI CONTROLLO ---
      final data = userDoc.data()!;
      final lastUpdateTimestamp = data['nameLastUpdatedAt'] as Timestamp?;

      if (lastUpdateTimestamp != null) {
        final now = DateTime.now();
        final lastUpdateDate = lastUpdateTimestamp.toDate();
        final difference = now.difference(lastUpdateDate);

        // Se la differenza è minore di 24 ore, lancia un'eccezione
        if (difference.inHours < 24) {
          throw const AuthenticationException("Puoi modificare il tuo nome solo una volta ogni 24 ore.");
        }
      }
      // Se il controllo passa, procedi con l'aggiornamento
      await firebaseUser.updateDisplayName(displayName);

      // Aggiorna sia il nome sia il timestamp dell'ultima modifica
      await userDocRef.update({
        'name': displayName,
        'nameLastUpdatedAt': FieldValue.serverTimestamp(), // Usa il timestamp del server
      });

    } on FirebaseException catch (e) {
      throw AuthenticationException("Errore durante l'aggiornamento del nome: ${e.message}");
    } on AuthenticationException {
      rethrow; // Rilancia l'eccezione del limite di tempo senza modificarla
    } catch (e) {
      throw const AuthenticationException("Si è verificato un errore imprevisto.");
    }
  }

  @override
  Future<String> updateUserPhoto(Uint8List photoFileBytes) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthenticationException("Utente non autenticato.");
    }

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        throw const AuthenticationException("Documento utente non trovato.");
      }

      // --- NUOVA LOGICA DI CONTROLLO PER LA FOTO ---
      final data = userDoc.data()!;
      final lastUpdateTimestamp = data['photoLastUpdatedAt'] as Timestamp?;

      if (lastUpdateTimestamp != null) {
        final now = DateTime.now();
        final lastUpdateDate = lastUpdateTimestamp.toDate();
        final difference = now.difference(lastUpdateDate);

        // Se la differenza è minore di 24 ore, lancia un'eccezione
        if (difference.inHours < 24) {
          throw const AuthenticationException("Puoi modificare la foto profilo solo una volta ogni 24 ore.");
        }
      }
      // --- FINE NUOVA LOGICA ---

      // Se il controllo passa, procedi con l'upload e l'aggiornamento
      final ref = _storage.ref('profile_pictures').child('${firebaseUser.uid}.jpg');
      await ref.putData(photoFileBytes);
      final photoURL = await ref.getDownloadURL();

      // Esegui gli aggiornamenti in parallelo
      await Future.wait([
        firebaseUser.updatePhotoURL(photoURL),
        // Aggiorna sia l'URL della foto sia il timestamp dell'ultima modifica
        userDocRef.update({
          'photoURL': photoURL,
          'photoLastUpdatedAt': FieldValue.serverTimestamp(), // Usa il timestamp del server
        }),
      ]);

      return photoURL;

    } on FirebaseException catch (e) {
      throw AuthenticationException("Errore durante l'aggiornamento della foto: ${e.message}");
    } on AuthenticationException {
      rethrow; // Rilancia l'eccezione del limite di tempo senza modificarla
    } catch (e) {
      throw const AuthenticationException("Si è verificato un errore imprevisto durante l'aggiornamento della foto.");
    }
  }

  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()..addScope('email')..addScope('profile');
      final credential = await _firebaseAuth.signInWithPopup(provider);
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthenticationException('Google sign in fallito.');
      }
      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (userDoc.exists) {
        return MyUser.fromEntity(MyUserEntity.fromDocument(userDoc.data()!));
      } else {
        return await _createUserFromFirebase(firebaseUser);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw const AuthenticationException('Errore di autenticazione Google.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw const AuthenticationException('Errore durante il logout.');
    }
  }

  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' => const AuthenticationException('Login annullato dall\'utente.'),
      'cancelled-popup-request' => const AuthenticationException('Login annullato.'),
      'network-request-failed' => const AuthenticationException('Errore di connessione.'),
      _ => AuthenticationException('Errore di autenticazione: ${e.message}'),
    };
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato da eliminare.');
    }
    try {
      final idToken = await user.getIdToken();
      final projectId = Firebase.app().options.projectId;
      final uri = Uri.https(
        '$kFunctionsRegion-$projectId.cloudfunctions.net',
        kDeleteUserFunctionName,
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(kApiTimeoutDuration);

      if (response.statusCode == 200) {
        await _firebaseAuth.signOut();
        return;
      } else {
        String serverMessage = 'Si è verificato un errore durante l\'eliminazione.';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] is String) {
            serverMessage = data['message'];
          }
        } catch (_) {}
        throw AuthenticationException(serverMessage);
      }
    } on TimeoutException {
      throw const AuthenticationException('La richiesta ha impiegato troppo tempo a rispondere. Controlla la tua connessione.');
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthenticationException) {
        rethrow;
      }
      throw const AuthenticationException('Errore di connessione o imprevisto.');
    }
  }
}


class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

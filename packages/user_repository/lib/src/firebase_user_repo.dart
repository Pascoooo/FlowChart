import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import '../user_repository.dart';

/// Regione Firebase Functions per le chiamate HTTP.
const String kFunctionsRegion = 'europe-west8';
/// Nome della Cloud Function per l'eliminazione dell'utente.
const String kDeleteUserFunctionName = 'delete_account_full';
/// Durata massima per le richieste API prima di un timeout.
const Duration kApiTimeoutDuration = Duration(seconds: 15);

/// Implementazione concreta di [UserRepository] che utilizza Firebase.
/// Gestisce autenticazione e dati profilo (Auth, Firestore, Storage) e delega
/// la cancellazione completa dell'account a una Cloud Function.
class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    required String googleClientId, // tenuto per compatibilità costruttore
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion) {
    _usersCollection = _firestore.collection('users');
  }

  /// Stream che emette l'utente corrente (`MyUser`) o `null`.
  /// Se l'utente è autenticato, ascolta il documento su Firestore.
  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(null);
      } else {
        return _usersCollection.doc(firebaseUser.uid).snapshots().map((snapshot) {
          if (!snapshot.exists) return null;
          return MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!));
        });
      }
    }).distinct();
  }

  /// Esegue il login con Google tramite popup.
  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()..addScope('email')..addScope('profile');
      final userCredential = await _firebaseAuth.signInWithPopup(provider);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw const AuthenticationException('Google sign in fallito: utente non ricevuto.');
      }

      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (userDoc.exists) {
        return MyUser.fromEntity(MyUserEntity.fromDocument(userDoc.data()!));
      } else {
        return await _createUserFromFirebase(firebaseUser);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (_) {
      throw const AuthenticationException('Si è verificato un errore imprevisto durante il login.');
    }
  }

  /// Logout dall'account corrente.
  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (_) {
      throw const AuthenticationException('Errore durante il logout.');
    }
  }

  /// Elimina l'account e tutti i dati associati delegando alla Cloud Function.
  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato da eliminare.');
    }

    try {
      final callable = _functions.httpsCallable(
        kDeleteUserFunctionName,
        options: HttpsCallableOptions(timeout: kApiTimeoutDuration),
      );
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? 'Errore del server durante l\'eliminazione.';
      throw AuthenticationException(message);
    } on TimeoutException {
      throw const AuthenticationException(
          'La richiesta ha impiegato troppo tempo. Controlla la tua connessione.');
    } catch (_) {
      throw const AuthenticationException('Errore di connessione o imprevisto durante l\'eliminazione.');
    }
  }

  /// Aggiorna il nome visualizzato dell'utente (max una volta ogni 24 ore).
  @override
  Future<void> updateUserDisplayName(String displayName) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw const AuthenticationException("Utente non autenticato.");
    if (displayName.trim().isEmpty) throw const AuthenticationException("Il nome non può essere vuoto.");

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) throw const AuthenticationException("Documento utente non trovato.");

      final data = userDoc.data()!;
      final lastUpdate = data['nameLastUpdatedAt'] as Timestamp?;
      if (lastUpdate != null && DateTime.now().difference(lastUpdate.toDate()).inHours < 24) {
        throw const AuthenticationException("Puoi modificare il nome solo una volta ogni 24 ore.");
      }

      await firebaseUser.updateDisplayName(displayName);
      await userDocRef.update({
        'name': displayName,
        'nameLastUpdatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AuthenticationException("Errore Firestore: ${e.message}");
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      throw const AuthenticationException("Errore imprevisto durante l'aggiornamento del nome.");
    }
  }

  /// Aggiorna la foto profilo (limite: una volta ogni 24 ore).
  @override
  Future<String> updateUserPhoto(Uint8List photoFileBytes) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) throw const AuthenticationException("Documento utente non trovato.");

      final data = userDoc.data()!;
      final lastUpdate = data['photoLastUpdatedAt'] as Timestamp?;
      if (lastUpdate != null && DateTime.now().difference(lastUpdate.toDate()).inHours < 24) {
        throw const AuthenticationException("Puoi modificare la foto solo una volta ogni 24 ore.");
      }

      final ref = _storage.ref('profile_pictures').child('${firebaseUser.uid}.jpg');
      await ref.putData(photoFileBytes);
      final photoURL = await ref.getDownloadURL();

      await Future.wait([
        firebaseUser.updatePhotoURL(photoURL),
        userDocRef.update({
          'photoURL': photoURL,
          'photoLastUpdatedAt': FieldValue.serverTimestamp(),
        }),
      ]);

      return photoURL;
    } on FirebaseException catch (e) {
      throw AuthenticationException("Errore Storage/Firestore: ${e.message}");
    } on AuthenticationException {
      rethrow;
    } catch (_) {
      throw const AuthenticationException("Errore imprevisto durante l'aggiornamento della foto.");
    }
  }

  /// Crea un nuovo documento utente in Firestore basato sui dati di Firebase Auth.
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

  /// Scrive o aggiorna i dati di un `MyUser` in Firestore.
  @override
  Future<void> setUserData(MyUser user) async {
    await _usersCollection.doc(user.userId).set(user.toEntity().toDocument());
  }

  /// Converte FirebaseAuthException in AuthenticationException con messaggi user-friendly.
  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' => const AuthenticationException('Login annullato dall\'utente.'),
      'cancelled-popup-request' => const AuthenticationException('Login annullato.'),
      'network-request-failed' => const AuthenticationException('Errore di connessione di rete.'),
      _ => AuthenticationException('Errore di autenticazione: ${e.message}'),
    };
  }
}

/// Eccezione custom per errori di autenticazione/utente.
class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

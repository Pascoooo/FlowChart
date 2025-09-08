import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../user_repository.dart';
import 'package:rxdart/rxdart.dart';

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _usersCollection = _firestore.collection('users');
  }

  /// Stream che emette l'utente corrente da Firestore in tempo reale.
  /// Si aggiorna sia al cambio di stato di autenticazione sia alle modifiche del profilo su Firestore.
  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) {
        // Se l'utente è sloggato, emetti null.
        return Stream.value(null);
      } else {
        // Altrimenti, ascolta le modifiche sul documento Firestore corrispondente.
        return _usersCollection
            .doc(firebaseUser.uid)
            .snapshots()
            .asyncMap((snapshot) {
          return _updateAndMapUser(firebaseUser, snapshot);
        });
      }
    }).distinct();
  }

  /// Funzione helper che controlla se il documento utente esiste in Firestore.
  /// Se non esiste, lo crea. Altrimenti, restituisce i dati da Firestore.
  Future<MyUser> _updateAndMapUser(User firebaseUser, DocumentSnapshot<Map<String, dynamic>> snapshot) async {
    if (!snapshot.exists || snapshot.data() == null) {
      // Il documento non esiste: è il primo login. Creiamolo.
      final newUser = MyUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? '',
      );
      // Non salvare dati vuoti
      if (!newUser.isEmpty) {
        await setUserData(newUser);
      }
      return newUser;
    } else {
      return MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!));
    }
  }

  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await _usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      final credential = await _firebaseAuth.signInWithPopup(provider);
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthenticationException('Google sign in fallito.');
      }

      // Lo stream `user` si occuperà automaticamente di creare/aggiornare il documento.
      // Restituiamo un oggetto MyUser temporaneo per la logica immediata post-login.
      return MyUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? '',
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw const AuthenticationException('Errore di autenticazione Google.');
    }
  }

  @override
  Future<MyUser?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return null;
    }
    final snapshot = await _usersCollection.doc(firebaseUser.uid).get();
    if (snapshot.exists && snapshot.data() != null) {
      return MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!));
    }

    final newUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );
    if(!newUser.isEmpty) {
      await setUserData(newUser);
    }
    return newUser.isEmpty ? null : newUser;
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 10));
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (kDebugMode) debugPrint('Sign out error: $e');
      throw const AuthenticationException('Errore durante il logout.');
    }
  }

  @override
  Future<String> getUid() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato');
    }
    return user.uid;
  }

  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' => const AuthenticationException('Login annullato dall\'utente.'),
      'cancelled-popup-request' => const AuthenticationException('Login annullato.'),
      'network-request-failed' => const AuthenticationException('Errore di connessione. Controlla la tua connessione e riprova.'),
      _ => AuthenticationException('Errore di autenticazione: ${e.message}'),
    };
  }
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

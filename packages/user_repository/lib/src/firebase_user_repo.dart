import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../user_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart';

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseDatabase _rtdb;
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseDatabase? rtdb,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
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
      throw const AuthenticationException('Nessun utente autenticato.');
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthenticationException(
            'Questa operazione richiede un login recente. Per favore, esegui nuovamente il logout e il login.');
      }
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      debugPrint('[deleteAccount] errore: $e');
      throw const AuthenticationException('Errore durante l\'eliminazione dell\'account.');
    }
  }
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}
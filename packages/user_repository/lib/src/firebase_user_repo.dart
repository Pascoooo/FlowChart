// dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../user_repository.dart';

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  late final CollectionReference _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _usersCollection = _firestore.collection('users');
  }

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth
        .authStateChanges()
        .distinct()
        .asyncMap(_mapFirebaseUserToMyUser)
        .handleError(_handleStreamError);
  }

  Future<MyUser?> _mapFirebaseUserToMyUser(User? firebaseUser) async {
    if (firebaseUser == null) {
      return null;
    }

    try {
      final myUser = MyUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? '',
      );

      if (myUser.isEmpty) {
        if (kDebugMode) debugPrint('Invalid user data: $myUser');
        return null;
      }

      await _saveUserToFirestore(myUser);
      return myUser;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error mapping Firebase user: $e');
      }
      rethrow;
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('User stream error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveUserToFirestore(MyUser user) async {
    try {
      await _usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save user: $e');
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

      if (credential.user == null) {
        throw const AuthenticationException('Google sign in fallito');
      }

      final firebaseUser = credential.user!;
      final myUser = MyUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? '',
      );

      // Salva l'utente solo se i dati sono validi
      if (myUser.isEmpty) {
        throw const AuthenticationException('Dati utente Google non validi.');
      }

      await _saveUserToFirestore(myUser);
      return myUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Sign In Error: $e');
      }
      throw const AuthenticationException('Errore di autenticazione Google.');
    }
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

  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' => const AuthenticationException('Login annullato dall\'utente.'),
      'cancelled-popup-request' => const AuthenticationException('Login annullato.'),
      'network-request-failed' => const AuthenticationException('Errore di connessione. Controlla la tua connessione e riprova.'),
      _ => AuthenticationException('Errore di autenticazione: ${e.message}'),
    };
  }

  // Metodi non più necessari per il flusso di autenticazione solo con Google
  @override
  Future<MyUser?> getCurrentUser() async => _mapFirebaseUserToMyUser(_firebaseAuth.currentUser);

  @override
  Future<void> setUserData(MyUser user) async => _saveUserToFirestore(user);

  @override
  Future<void> sendEmailLink(String email) async => throw UnimplementedError();

  @override
  Future<MyUser> signInWithEmailLink(String email, String emailLink) async => throw UnimplementedError();

  @override
  bool isEmailLink(String link) => throw UnimplementedError();

  @override
  Future<String> getUid() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato');
    }
    return user.uid;
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
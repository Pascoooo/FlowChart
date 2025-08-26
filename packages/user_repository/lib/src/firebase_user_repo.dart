// dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../user_repository.dart';

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final usersCollection = FirebaseFirestore.instance.collection('users');

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      await firebaseUser.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser == null) return null;

      final myUser = MyUser(
        userId: refreshedUser.uid,
        email: refreshedUser.email ?? '',
        name: refreshedUser.displayName ?? '',
        photoURL: refreshedUser.photoURL ?? '',
      );

      await usersCollection.doc(refreshedUser.uid).set(
        myUser.toEntity().toDocument(),
        SetOptions(merge: true),
      );
      return myUser;
    });
  }

  @override
  Future<String> getUid() async {
    final u = _firebaseAuth.currentUser;
    if (u == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Nessun utente autenticato',
      );
    }
    return u.uid;
  }

  @override
  Future<MyUser?> getCurrentUser() async {
    final u = _firebaseAuth.currentUser;
    if (u == null) return null;
    return MyUser(
      userId: u.uid,
      email: u.email ?? '',
      name: u.displayName ?? '',
      photoURL: u.photoURL ?? '',
    );
  }

  @override
  Future<void> setUserData(MyUser user) async {
    await usersCollection
        .doc(user.userId)
        .set(user.toEntity().toDocument(), SetOptions(merge: true));
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      UserCredential credential;

      try {
        credential = await _firebaseAuth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          throw FirebaseAuthException(
            code: e.code,
            message: 'Login annullato dall\'utente',
          );
        }
        rethrow;
      }

      if (credential.user == null) {
        throw FirebaseAuthException(
          code: 'sign_in_failed',
          message: 'Google sign in failed',
        );
      }

      return await _saveFirebaseUser(credential.user!);
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendEmailLink(String email) async {
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: '${Uri.base.origin}/#/finish-signin',
        handleCodeInApp: true,
      );

      await _firebaseAuth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      debugPrint('Email link sent to: $email');
    } catch (e) {
      debugPrint('Send Email Link Error: $e');
      rethrow;
    }
  }

  @override
  Future<MyUser> signInWithEmailLink(String email, String emailLink) async {
    try {
      if (!_firebaseAuth.isSignInWithEmailLink(emailLink)) {
        throw FirebaseAuthException(
          code: 'invalid-email-link',
          message: 'Invalid email link',
        );
      }

      final credential = await _firebaseAuth.signInWithEmailLink(
        email: email,
        emailLink: emailLink,
      );

      if (credential.user == null) {
        throw FirebaseAuthException(
          code: 'sign_in_failed',
          message: 'Email link sign in failed',
        );
      }

      return await _saveFirebaseUser(credential.user!);
    } catch (e) {
      debugPrint('Sign In with Email Link Error: $e');
      rethrow;
    }
  }

  @override
  bool isEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  Future<MyUser> _saveFirebaseUser(User firebaseUser) async {
    final myUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );

    await usersCollection.doc(myUser.userId).set(
      myUser.toEntity().toDocument(),
      SetOptions(merge: true),
    );

    return myUser;
  }
}
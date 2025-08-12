import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../user_repository.dart';

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final usersCollection = FirebaseFirestore.instance.collection('users');

  FirebaseUserRepo({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().asyncExpand((firebaseUser) async* {
      if (firebaseUser == null) {
        yield MyUser.empty;
      } else {
        final docRef = usersCollection.doc(firebaseUser.uid);
        final snap = await docRef.get();
        if (!snap.exists) {
          final newUser = MyUser(
            userId: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ?? '',
            photoURL: firebaseUser.photoURL ?? '',
          );
          await setUserData(newUser);
          yield newUser;
        } else {
          yield MyUser.fromEntity(MyUserEntity.fromDocument(snap.data()!));
        }
      }
    });
  }

  @override
  Future<String> getUid() async {
    return _firebaseAuth.currentUser!.uid;
  }

  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument());
    } catch (e) {
      log('Error setting user data: $e');
      rethrow;
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<MyUser> signUp(MyUser myUser, String password) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: myUser.email, password: password);
    myUser.userId = userCredential.user!.uid;
    return myUser;
  }

  @override
  Future<MyUser> signInWithGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      credential = await _firebaseAuth.signInWithPopup(googleProvider);
    } else {
      throw UnsupportedError('Google sign-in su mobile richiede il package google_sign_in');
    }
    final firebaseUser = credential.user!;
    final myUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );
    await usersCollection.doc(firebaseUser.uid).set(myUser.toEntity().toDocument(), SetOptions(merge: true));
    return myUser;
  }

  @override
  Future<MyUser> signInWithGitHub() async {
    UserCredential credential;
    final githubProvider = GithubAuthProvider();
    githubProvider.addScope('read:user');
    githubProvider.addScope('user:email');
    if (kIsWeb) {
      credential = await _firebaseAuth.signInWithPopup(githubProvider);
    } else {
      credential = await _firebaseAuth.signInWithProvider(githubProvider);
    }
    final firebaseUser = credential.user!;
    final myUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );
    await usersCollection.doc(firebaseUser.uid).set(myUser.toEntity().toDocument(), SetOptions(merge: true));
    return myUser;
  }
}
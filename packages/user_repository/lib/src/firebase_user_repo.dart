import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user_repository.dart'; // MyUser, MyUserEntity, UserRepository

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final usersCollection = FirebaseFirestore.instance.collection('users');

  FirebaseUserRepo({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final myUser = MyUser(
        userId: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        photoURL: firebaseUser.photoURL ?? '',
      );

      // Aggiorna Firestore senza bloccare la risposta
      usersCollection.doc(firebaseUser.uid).set(
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


  Future<MyUser> _saveFirebaseUser(User firebaseUser) async {
    final myUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
    );

    await usersCollection
        .doc(myUser.userId)
        .set(myUser.toEntity().toDocument(), SetOptions(merge: true));

    return myUser;
  }

  @override
  Future<void> setUserData(MyUser user) async {
    await usersCollection
        .doc(user.userId)
        .set(user.toEntity().toDocument(), SetOptions(merge: true));
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut(); // su web basta questo
  }

  /// Login con email/password
  @override
  Future<MyUser> signIn(String email, String password) async {
    final userCred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _saveFirebaseUser(userCred.user!);
  }

  /// Registrazione con email/password
  @override
  Future<MyUser> signUp(MyUser myUser, String password) async {
    final userCred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: myUser.email,
      password: password,
    );
    final createdUser = myUser..userId = userCred.user!.uid;
    await setUserData(createdUser);
    return createdUser;
  }

  @override
  Future<MyUser> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    final userCred = await _firebaseAuth.signInWithPopup(provider);
    return _saveFirebaseUser(userCred.user!);
  }
}

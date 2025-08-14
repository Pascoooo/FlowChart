import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../user_repository.dart'; // MyUser, MyUserEntity, UserRepository

class FirebaseUserRepo implements UserRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final usersCollection = FirebaseFirestore.instance.collection('users');

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

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

    // Estrai i provider dall'utente Firebase
    final providers = firebaseUser.providerData
        .map((provider) => provider.providerId)
        .toList();

    await usersCollection.doc(myUser.userId).set({
      ...myUser.toEntity().toDocument(),
      'providers': providers, // Salva i provider
      'lastSignIn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  /// Verifica se un'email esiste già nel database
  Future<bool> _emailExists(String email) async {
    try {
      final query = await usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Ottiene i provider di un utente dal database
  Future<List<String>> _getUserProviders(String email) async {
    try {
      final query = await usersCollection
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return [];

      final userData = query.docs.first.data();
      return List<String>.from(userData['providers'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Link account email/password a account Google esistente
  Future<MyUser> _linkEmailPasswordToCurrentUser(String email, String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nessun utente autenticato');

    final credential = EmailAuthProvider.credential(email: email, password: password);
    final userCredential = await user.linkWithCredential(credential);

    // Aggiorna il nome se non presente
    if (user.displayName == null || user.displayName!.isEmpty) {
      await user.updateDisplayName(email.split('@')[0]);
    }

    return _saveFirebaseUser(userCredential.user!);
  }

  /// Link account Google a account email/password esistente
  Future<MyUser> _linkGoogleToCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Nessun utente autenticato');

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Login Google annullato');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await user.linkWithCredential(credential);
    return _saveFirebaseUser(userCredential.user!);
  }

  /// Login con email/password
  @override
  Future<MyUser> signIn(String email, String password) async {
    try {
      final userCred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _saveFirebaseUser(userCred.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Verifica se esiste un account Google con questa email
        final providers = await _getUserProviders(email);
        if (providers.contains('google.com')) {
          throw FirebaseAuthException(
            code: 'account-exists-with-google',
            message: 'Account esistente con Google. Usa il login Google.',
          );
        }
      }
      rethrow;
    }
  }

  /// Registrazione con email/password
  @override
  Future<MyUser> signUp(MyUser myUser, String password) async {
    try {
      final userCred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: myUser.email,
        password: password,
      );

      // Aggiorna il displayName se fornito
      if (myUser.name.isNotEmpty) {
        await userCred.user!.updateDisplayName(myUser.name);
      }

      final createdUser = myUser..userId = userCred.user!.uid;
      await setUserData(createdUser);
      return createdUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Verifica se l'utente è già loggato con Google con la stessa email
        final currentUser = _firebaseAuth.currentUser;
        if (currentUser != null && currentUser.email == myUser.email) {
          // L'utente è già loggato con Google, linko l'account email/password
          return await _linkEmailPasswordToCurrentUser(myUser.email, password);
        }

        // Verifica i provider per questa email usando Firestore
        final providers = await _getUserProviders(myUser.email);
        if (providers.contains('google.com')) {
          throw FirebaseAuthException(
            code: 'account-exists-with-google',
            message: 'Account già esistente con Google. Fai login con Google prima.',
          );
        } else if (providers.contains('password')) {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email già registrata. Fai login con email e password.',
          );
        }

        // Se l'email esiste ma non abbiamo info sui provider, gestisci genericamente
        final emailExists = await _emailExists(myUser.email);
        if (emailExists) {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'Email già registrata. Prova a fare login.',
          );
        }
      }
      rethrow;
    }
  }

  /// Login con Google
  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Login Google annullato');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _firebaseAuth.signInWithCredential(credential);
      return _saveFirebaseUser(userCred.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        if (email != null) {
          // Verifica se c'è un account email/password esistente usando Firestore
          final providers = await _getUserProviders(email);
          if (providers.contains('password')) {
            throw FirebaseAuthException(
              code: 'account-exists-with-password',
              message: 'Account esistente con email/password. Fai login con email e password prima.',
            );
          }
        }
      }
      rethrow;
    }
  }

  /// Link Google account all'utente corrente (da chiamare dopo login email/password)
  @override
  Future<MyUser> linkWithGoogle() async {
    try {
      return await _linkGoogleToCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw FirebaseAuthException(
          code: 'provider-already-linked',
          message: 'Account Google già collegato.',
        );
      }
      rethrow;
    }
  }

  /// Link email/password all'utente corrente (da chiamare dopo login Google)
  @override
  Future<MyUser> linkWithEmailPassword(String email, String password) async {
    try {
      return await _linkEmailPasswordToCurrentUser(email, password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        throw FirebaseAuthException(
          code: 'provider-already-linked',
          message: 'Email/password già collegata.',
        );
      }
      rethrow;
    }
  }

  /// Verifica se l'utente corrente ha un provider specifico collegato
  @override
  Future<bool> hasProvider(String providerId) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;

    return user.providerData.any((provider) => provider.providerId == providerId);
  }

  /// Ottiene i provider collegati all'utente corrente
  @override
  Future<List<String>> getLinkedProviders() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return [];

    return user.providerData.map((provider) => provider.providerId).toList();
  }
}
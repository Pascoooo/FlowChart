import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import '../user_repository.dart';

/// Regione Firebase Functions per le chiamate HTTP.
const String kFunctionsRegion = 'europe-west8';
/// Scope di Google Drive per consentire la creazione di file.
const String kDriveScope = 'https://www.googleapis.com/auth/drive.file';
/// Nome della Cloud Function per l'eliminazione dell'utente.
const String kDeleteUserFunctionName = 'deleteUserAuthCallable';
/// Durata massima per le richieste API prima di un timeout.
const Duration kApiTimeoutDuration = Duration(seconds: 15);


// --- Implementazione del Repository ---

/// Implementazione concreta di [UserRepository] che utilizza Firebase.
///
/// Gestisce l'autenticazione, la gestione dei dati utente su Firestore
/// e le interazioni con le API di Google Drive.
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
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion) {
    _usersCollection = _firestore.collection('users');
  }


  /// Stream che emette l'utente corrente (`MyUser`) o `null`.
  ///
  /// Si mette in ascolto dei cambiamenti di stato di Firebase Auth.
  /// Se l'utente è autenticato, si collega al suo documento Firestore per
  /// fornire aggiornamenti in tempo reale sul profilo.
  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) {
        return Stream.value(null);
      } else {
        return _usersCollection.doc(firebaseUser.uid).snapshots().map((snapshot) =>
        snapshot.exists ? MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!)) : null);
      }
    }).distinct();
  }

  /// Esegue il login con Google tramite un popup.
  ///
  /// Se l'utente è nuovo, crea il suo documento su Firestore.
  /// Se l'utente esiste già, restituisce i dati esistenti.
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
    } catch (e) {
      throw const AuthenticationException('Si è verificato un errore imprevisto durante il login.');
    }
  }

  /// Esegue il logout dell'utente corrente.
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

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato da eliminare.');
    }

    try {
      // La chiamata rimane invariata, ma ora funzionerà correttamente
      final callable = _functions.httpsCallable(
        kDeleteUserFunctionName,
        options: HttpsCallableOptions(timeout: kApiTimeoutDuration),
      );
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
      // La gestione degli errori ora è più pulita
      final message = e.message ?? 'Errore del server durante l\'eliminazione.';
      throw AuthenticationException(message);
    } on TimeoutException {
      throw const AuthenticationException('La richiesta ha impiegato troppo tempo. Controlla la tua connessione.');
    } catch (e) {
      throw const AuthenticationException('Errore di connessione o imprevisto durante l\'eliminazione.');
    }
  }

  /// Aggiorna il nome visualizzato dell'utente.
  ///
  /// Impone un limite di una modifica ogni 24 ore.
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

  /// Aggiorna la foto profilo dell'utente.
  ///
  /// Carica il file su Firebase Storage e aggiorna gli URL su Auth e Firestore.
  /// Impone un limite di una modifica ogni 24 ore.
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

  /// Richiede all'utente il permesso di accedere a Google Drive.
  ///
  /// Se concesso, imposta `driveConnected` a `true` nel documento Firestore dell'utente.
  /// Restituisce `true` se il permesso è stato concesso, `false` se l'utente ha annullato.
  @override
  Future<bool> requestGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      final provider = GoogleAuthProvider()..addScope(kDriveScope);
      await user.reauthenticateWithPopup(provider);

      await _usersCollection.doc(user.uid).update({'driveConnected': true});
      return true;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return false;
      }
      throw AuthenticationException("Errore durante la richiesta di permessi: ${e.message}");
    } catch (_) {
      throw const AuthenticationException("Si è verificato un errore imprevisto.");
    }
  }

  /// Revoca i permessi di accesso a Google Drive.
  ///
  /// Chiama l'endpoint di revoca di Google e imposta `driveConnected` a `false`
  /// nel documento Firestore dell'utente, indipendentemente dall'esito della chiamata API.
  @override
  Future<void> revokeGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      final provider = GoogleAuthProvider();
      final userCredential = await user.reauthenticateWithPopup(provider);
      final accessToken = userCredential.credential?.accessToken;

      if (accessToken == null) {
        throw const AuthenticationException("Impossibile ottenere il token per la revoca.");
      }

      await http.post(
        Uri.parse('https://oauth2.googleapis.com/revoke'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': accessToken},
      );

    } finally {
      await _usersCollection.doc(user.uid).update({'driveConnected': false});
    }
  }

  /// Carica un file su Google Drive nella cartella dell'applicazione.
  @override
  Future<void> uploadFileToDrive(String fileName, Uint8List fileBytes) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException("User not authenticated.");
    }

    try {
      final provider = GoogleAuthProvider()..addScope(kDriveScope);
      final userCredential = await user.reauthenticateWithPopup(provider);
      final accessToken = userCredential.credential?.accessToken;

      if (accessToken == null) {
        throw const AuthenticationException("Could not obtain a valid access token for Google Drive.");
      }

      final authHeaders = {'Authorization': 'Bearer $accessToken'};
      final client = AuthenticatedHttpClient(http.Client(), authHeaders);
      final driveApi = drive.DriveApi(client);

      final fileToUpload = drive.File()..name = fileName;
      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);

      await driveApi.files.create(fileToUpload, uploadMedia: media);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthenticationException("Upload canceled by user.");
      }
      throw AuthenticationException("Firebase authentication error during upload: ${e.message}");
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      throw AuthenticationException("Failed to upload to Google Drive: ${e.toString()}");
    }
  }

  /// Crea un nuovo documento utente in Firestore basato sui dati di Firebase Auth.
  ///
  Future<MyUser> _createUserFromFirebase(User firebaseUser) async {
    final newUser = MyUser(
      userId: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      photoURL: firebaseUser.photoURL ?? '',
      driveConnected: false,
    );
    await setUserData(newUser);
    return newUser;
  }

  /// Scrive o aggiorna i dati di un `MyUser` in Firestore.
  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await _usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument());
    } catch (e) {
      rethrow;
    }
  }

  /// Converte le eccezioni di [FirebaseAuthException] in [AuthenticationException] più leggibili.
  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'popup-closed-by-user' => const AuthenticationException('Login annullato dall\'utente.'),
      'cancelled-popup-request' => const AuthenticationException('Login annullato.'),
      'network-request-failed' => const AuthenticationException('Errore di connessione di rete.'),
      _ => AuthenticationException('Errore di autenticazione: ${e.message}'),
    };
  }
}



/// Un client HTTP che wrappa un altro client e aggiunge gli header di autenticazione
/// di Google a ogni richiesta inviata. Indispensabile per usare le `googleapis`.
class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _authHeaders;

  AuthenticatedHttpClient(this._inner, this._authHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_authHeaders);
    return _inner.send(request);
  }
}

/// Eccezione custom per errori specifici legati all'autenticazione
/// e alla gestione dell'utente nell'applicazione.
class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}
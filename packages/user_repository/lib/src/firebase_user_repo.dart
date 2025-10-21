import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import '../user_repository.dart';
import 'google_drive_service.dart';

/// Regione Firebase Functions per le chiamate HTTP.
const String kFunctionsRegion = 'europe-west8';
/// Nome della Cloud Function per l'eliminazione dell'utente.
const String kDeleteUserFunctionName = 'delete_account_full';
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
  late final GoogleDriveService _driveService;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    required String googleClientId,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion) {
    _usersCollection = _firestore.collection('users');
    _driveService = GoogleDriveService(
      functions: _functions,
      googleClientId: googleClientId,
    );
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

  /// Elimina l'account dell'utente corrente e tutti i dati associati.
  ///
  /// Utilizza una Cloud Function (`delete_account_full`) per garantire
  /// l'eliminazione sicura dei dati su Auth, Firestore, RTDB, Storage e copia pubblica.
  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException('Nessun utente autenticato da eliminare.');
    }

    try {
      // Metodo raccomandato utilizzando il SDK di Firebase Functions
      final callable = _functions.httpsCallable(
        kDeleteUserFunctionName,
        options: HttpsCallableOptions(timeout: kApiTimeoutDuration),
      );
      await callable.call();
    } on FirebaseFunctionsException catch (e) {
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
  /// Utilizza GoogleDriveService per ottenere il serverAuthCode e inviarlo
  /// al backend per lo scambio con i token OAuth2.
  /// Se concesso, imposta `driveConnected` a `true` nel documento Firestore dell'utente.
  /// Restituisce `true` se il permesso è stato concesso, `false` se l'utente ha annullato.
  @override
  Future<bool> requestGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      // Usa il GoogleDriveService per gestire il flusso OAuth2
      final granted = await _driveService.requestDrivePermission(user.uid);

      if (granted) {
        // Aggiorna Firestore per riflettere la connessione
        await _usersCollection.doc(user.uid).update({'driveConnected': true});
        return true;
      }

      return false;

    } catch (e) {
      throw AuthenticationException(
        "Errore durante la richiesta di permessi Drive: ${e.toString()}"
      );
    }
  }

  /// Revoca i permessi di accesso a Google Drive.
  ///
  /// Utilizza GoogleDriveService per disconnettere l'account e eliminare i token dal backend.
  /// Imposta `driveConnected` a `false` nel documento Firestore dell'utente.
  @override
  Future<void> revokeGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      await _driveService.revokeDrivePermission(user.uid);
    } catch (e) {
      // Log l'errore ma continua comunque
      print('Warning: Error revoking Drive permission: $e');
    } finally {
      // Aggiorna sempre lo stato su Firestore
      await _usersCollection.doc(user.uid).update({'driveConnected': false});
    }
  }

  /// Carica un file su Google Drive nella cartella dell'applicazione.
  ///
  /// Questo metodo funziona come proxy: invia i dati al backend che gestisce
  /// le chiamate API a Google Drive usando i token salvati in modo sicuro.
  @override
  Future<void> uploadFileToDrive(String fileName, Uint8List fileBytes) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException("Utente non autenticato.");
    }

    // Verifica che l'utente abbia connesso Drive
    final userDoc = await _usersCollection.doc(user.uid).get();
    if (!userDoc.exists || userDoc.data()?['driveConnected'] != true) {
      throw const AuthenticationException(
        "Devi prima connettere Google Drive nelle impostazioni."
      );
    }

    try {
      final result = await _driveService.uploadFileToDrive(
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: 'image/png',
      );

      // Successo - il file è stato caricato
      print('File uploaded successfully: ${result['webViewLink']}');

    } catch (e) {
      throw AuthenticationException(
        "Errore durante l'upload su Drive: ${e.toString()}"
      );
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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import '../user_repository.dart';

// --- Costanti Globali ---

/// Regione Firebase Functions per le chiamate HTTP.
const String kFunctionsRegion = 'europe-west8';
/// Scope di Google Drive per consentire la creazione di file.
const String kDriveScope = 'https://www.googleapis.com/auth/drive.file';
/// Nome della Cloud Function per l'eliminazione dell'utente.
const String kDeleteUserFunctionName = 'deleteUserAuthHttp';
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
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  FirebaseUserRepo({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance {
    _usersCollection = _firestore.collection('users');
  }

  //________________________________________________________________________________
  // Sezione: Flusso Utente Principale
  //________________________________________________________________________________

  @override
  Stream<MyUser?> get user {
    return _firebaseAuth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) {
        // Se l'utente non è autenticato, emette `null`.
        return Stream.value(null);
      } else {
        // Altrimenti, si mette in ascolto del documento utente su Firestore
        // per emettere aggiornamenti in tempo reale (es. cambio nome, connessione a Drive).
        return _usersCollection.doc(firebaseUser.uid).snapshots().map((snapshot) =>
        snapshot.exists ? MyUser.fromEntity(MyUserEntity.fromDocument(snapshot.data()!)) : null);
      }
    }).distinct(); // Emette solo se l'oggetto utente è effettivamente cambiato.
  }

  //________________________________________________________________________________
  // Sezione: Metodi di Autenticazione
  //________________________________________________________________________________

  @override
  Future<MyUser> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider()..addScope('email')..addScope('profile');
      final userCredential = await _firebaseAuth.signInWithPopup(provider);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw const AuthenticationException('Google sign in fallito: utente non ricevuto.');
      }

      // Controlla se l'utente esiste già in Firestore.
      final userDoc = await _usersCollection.doc(firebaseUser.uid).get();
      if (userDoc.exists) {
        // Se esiste, restituisce i dati esistenti.
        return MyUser.fromEntity(MyUserEntity.fromDocument(userDoc.data()!));
      } else {
        // Altrimenti, crea un nuovo documento per il nuovo utente.
        return await _createUserFromFirebase(firebaseUser);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw const AuthenticationException('Si è verificato un errore imprevisto durante il login.');
    }
  }

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
      // Ottiene il token ID JWT per autenticare la richiesta alla Cloud Function.
      final idToken = await user.getIdToken();
      final projectId = Firebase.app().options.projectId;

      // Costruisce l'URL della Cloud Function.
      final uri = Uri.https(
        '$kFunctionsRegion-$projectId.cloudfunctions.net',
        kDeleteUserFunctionName,
      );

      // Esegue la chiamata HTTP sicura.
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{}),
      ).timeout(kApiTimeoutDuration);

      if (response.statusCode != 200) {
        // Se la funzione fallisce, tenta di leggere il messaggio di errore dal corpo della risposta.
        String serverMessage = 'Errore del server durante l\'eliminazione.';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] is String) {
            serverMessage = data['message'];
          }
        } catch (_) {}
        throw AuthenticationException(serverMessage);
      }

      // Se la funzione ha successo (status 200), il backend ha già eliminato l'utente.
      // Eseguiamo il logout localmente per completare il processo.
      await _firebaseAuth.signOut();

    } on TimeoutException {
      throw const AuthenticationException('La richiesta ha impiegato troppo tempo. Controlla la tua connessione.');
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on AuthenticationException {
      rethrow; // Rilancia le eccezioni già gestite.
    } catch (e) {
      throw const AuthenticationException('Errore di connessione o imprevisto durante l\'eliminazione.');
    }
  }


  //________________________________________________________________________________
  // Sezione: Gestione Profilo Utente
  //________________________________________________________________________________

  @override
  Future<void> updateUserDisplayName(String displayName) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw const AuthenticationException("Utente non autenticato.");
    if (displayName.trim().isEmpty) throw const AuthenticationException("Il nome non può essere vuoto.");

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) throw const AuthenticationException("Documento utente non trovato.");

      // Logica di Rate-Limiting: controlla quando è stata l'ultima modifica.
      final data = userDoc.data()!;
      final lastUpdate = data['nameLastUpdatedAt'] as Timestamp?;
      if (lastUpdate != null && DateTime.now().difference(lastUpdate.toDate()).inHours < 24) {
        throw const AuthenticationException("Puoi modificare il nome solo una volta ogni 24 ore.");
      }

      // Aggiorna sia l'oggetto User di Firebase Auth che il documento Firestore.
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

  @override
  Future<String> updateUserPhoto(Uint8List photoFileBytes) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      final userDocRef = _usersCollection.doc(firebaseUser.uid);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) throw const AuthenticationException("Documento utente non trovato.");

      // Logica di Rate-Limiting: controlla quando è stata l'ultima modifica.
      final data = userDoc.data()!;
      final lastUpdate = data['photoLastUpdatedAt'] as Timestamp?;
      if (lastUpdate != null && DateTime.now().difference(lastUpdate.toDate()).inHours < 24) {
        throw const AuthenticationException("Puoi modificare la foto solo una volta ogni 24 ore.");
      }

      // Carica la nuova immagine su Firebase Storage.
      final ref = _storage.ref('profile_pictures').child('${firebaseUser.uid}.jpg');
      await ref.putData(photoFileBytes);
      final photoURL = await ref.getDownloadURL();

      // Esegue gli aggiornamenti in parallelo per efficienza.
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

  //________________________________________________________________________________
  // Sezione: Integrazione Google Drive
  //________________________________________________________________________________

  @override
  Future<bool> requestGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      // Richiede una ri-autenticazione forzando la richiesta del nuovo scope per Drive.
      final provider = GoogleAuthProvider()..addScope(kDriveScope);
      await user.reauthenticateWithPopup(provider);

      // Se l'utente concede il permesso, aggiorniamo il suo stato su Firestore.
      await _usersCollection.doc(user.uid).set(
        {'driveConnected': true},
        SetOptions(merge: true),
      );
      return true;

    } on FirebaseAuthException catch (e) {
      // Se l'utente chiude il popup, non è un errore, ma un'azione intenzionale.
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return false;
      }
      throw AuthenticationException("Errore durante la richiesta di permessi: ${e.message}");
    } catch (_) {
      throw const AuthenticationException("Si è verificato un errore imprevisto.");
    }
  }

  @override
  Future<void> revokeGoogleDrivePermission() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthenticationException("Utente non autenticato.");

    try {
      // Per revocare un token è necessario un token di accesso valido.
      // La ri-autenticazione è il modo più sicuro per ottenerne uno nuovo.
      final provider = GoogleAuthProvider();
      final userCredential = await user.reauthenticateWithPopup(provider);
      final accessToken = userCredential.credential?.accessToken;

      if (accessToken == null) {
        throw const AuthenticationException("Impossibile ottenere il token per la revoca.");
      }

      // Chiama l'endpoint di revoca di Google.
      await http.post(
        Uri.parse('https://oauth2.googleapis.com/revoke'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'token': accessToken},
      );

    } finally {
      // Indipendentemente dal successo della chiamata API (il token potrebbe essere già scaduto),
      // aggiorniamo lo stato interno dell'applicazione per riflettere la disconnessione.
      await _usersCollection.doc(user.uid).set(
        {'driveConnected': false},
        SetOptions(merge: true),
      );
    }
  }

  @override
  Future<void> uploadFileToDrive(String fileName, Uint8List fileBytes) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthenticationException("User not authenticated.");
    }

    try {
      // 1. Re-authenticate with Firebase to get a fresh, valid credential.
      // This is the correct way to get the access token within your architecture.
      // If the user has already granted permission, this popup will be brief.
      final provider = GoogleAuthProvider()..addScope(kDriveScope);
      final userCredential = await user.reauthenticateWithPopup(provider);

      final accessToken = userCredential.credential?.accessToken;

      if (accessToken == null) {
        throw const AuthenticationException("Could not obtain a valid access token for Google Drive.");
      }

      // 2. Create an authenticated HTTP client with the obtained token.
      final authHeaders = {'Authorization': 'Bearer $accessToken'};
      final client = AuthenticatedHttpClient(http.Client(), authHeaders);
      final driveApi = drive.DriveApi(client);

      // 3. Create file metadata and upload.
      final fileToUpload = drive.File()..name = fileName;
      final media = drive.Media(Stream.value(fileBytes), fileBytes.length);

      await driveApi.files.create(fileToUpload, uploadMedia: media);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthenticationException("Upload canceled by user.");
      }
      // Handle other Firebase-specific errors
      throw AuthenticationException("Firebase authentication error during upload: ${e.message}");
    } on AuthenticationException {
      rethrow; // Re-throw exceptions you've already handled.
    } catch (e) {
      // Catch-all for network errors or other issues
      throw AuthenticationException("Failed to upload to Google Drive: ${e.toString()}");
    }
  }
  //________________________________________________________________________________
  // Sezione: Metodi Ausiliari Interni
  //________________________________________________________________________________

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

  @override
  Future<void> setUserData(MyUser user) async {
    try {
      await _usersCollection
          .doc(user.userId)
          .set(user.toEntity().toDocument(), SetOptions(merge: true));
    } catch (e) {
      // Rilancia l'eccezione per essere gestita dal chiamante.
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


// --- Classi di Utilità ---

/// Un client HTTP che wrappa un altro client e aggiunge gli header di autenticazione
/// di Google a ogni richiesta inviata. Indispensabile per usare le `googleapis`.
class AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _authHeaders;

  AuthenticatedHttpClient(this._inner, this._authHeaders);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Aggiunge gli header di autenticazione alla richiesta originale prima di inviarla.
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
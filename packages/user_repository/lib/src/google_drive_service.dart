import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Costanti per Google Drive
const String kDriveScope = 'https://www.googleapis.com/auth/drive.file';
const String kFunctionsRegion = 'europe-west8';

/// Service dedicato alla gestione dell'integrazione con Google Drive.
///
/// Implementa il flusso OAuth2 server-side conformemente alle direttive GIS.
/// Su web, utilizza Firebase Auth per ottenere token temporanei che vengono
/// immediatamente scambiati dal backend per refresh token permanenti.
class GoogleDriveService {
  final FirebaseFunctions _functions;

  GoogleDriveService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  /// Richiede il permesso per Google Drive tramite popup OAuth.
  ///
  /// Processo:
  /// 1. Mostra il consent screen di Google con lo scope Drive
  /// 2. Ottiene access token e ID token temporanei
  /// 3. Li invia al backend che li scambia per refresh token
  /// 4. Il backend salva i token in modo sicuro in Firestore
  ///
  /// Restituisce `true` se il permesso è stato concesso con successo,
  /// `false` se l'utente ha annullato l'operazione.
  Future<bool> requestDrivePermission(String userId) async {
    try {
      // Ottieni l'utente corrente da Firebase Auth
      final firebaseAuth = FirebaseAuth.instance;
      final user = firebaseAuth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Configura il provider con lo scope Drive
      final provider = GoogleAuthProvider()
        ..addScope(kDriveScope)
        ..setCustomParameters({
          'access_type': 'offline', // Richiede refresh token
          'prompt': 'consent', // Forza il consent screen
        });

      // Mostra il popup di autorizzazione
      final userCredential = await user.reauthenticateWithPopup(provider);

      // Ottieni i token dal risultato
      final accessToken = userCredential.credential?.accessToken;
      final idToken = await user.getIdToken();

      if (accessToken == null) {
        throw Exception('Failed to obtain access token from Google');
      }

      // Invia i token al backend per lo scambio
      final callable = _functions.httpsCallable(
        'exchangeGoogleTokens',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      final result = await callable.call({
        'accessToken': accessToken,
        'idToken': idToken,
      });

      return result.data['success'] == true;
    } on FirebaseAuthException catch (e) {
      // L'utente ha annullato il popup
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return false;
      }
      throw Exception('Firebase Auth error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Carica un file su Google Drive tramite il backend.
  ///
  /// Questo metodo è un proxy: invia i dati al backend che gestisce
  /// tutte le chiamate API a Google Drive usando i token salvati.
  Future<Map<String, dynamic>> uploadFileToDrive({
    required String userId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/json',
  }) async {
    try {
      // Converti i byte in base64 per il trasporto JSON
      final String base64FileData = base64Encode(fileBytes);

      final callable = _functions.httpsCallable(
        'uploadFileToDrive',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final result = await callable.call({
        'fileName': fileName,
        'fileData': base64FileData,
        'mimeType': mimeType,
      });

      return {
        'success': true,
        'fileId': result.data['fileId'],
        'webViewLink': result.data['webViewLink'],
      };
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw Exception('Session expired. Please sign in again.');
      } else if (e.code == 'permission-denied') {
        throw Exception('Google Drive permissions revoked. Please reconnect.');
      }
      throw Exception('Upload error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      throw Exception('Network or unexpected error: ${e.toString()}');
    }
  }

  /// Revoca i permessi di Google Drive.
  ///
  /// Richiede al backend di eliminare i token salvati.
  Future<void> revokeDrivePermission(String userId) async {
    try {
      final callable = _functions.httpsCallable(
        'revokeGoogleDrivePermission',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );

      await callable.call({});
    } catch (e) {
      rethrow;
    }
  }
}

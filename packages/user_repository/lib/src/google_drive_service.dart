import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Costanti per Google Drive
const String kDriveScope = 'https://www.googleapis.com/auth/drive.file';
const String kFunctionsRegion = 'europe-west8';

@JS('google.accounts.oauth2')
@staticInterop
class GsiAuth2 {}

extension GsiAuth2Extension on GsiAuth2 {
  external JSAny initCodeClient(JSObject config);
  external void revoke(String accessToken, JSFunction doneFn);
}


@JS()
@anonymous
@staticInterop
class CodeClient {}

extension CodeClientExtension on CodeClient {
  external void requestCode();
}

@JS()
@anonymous
@staticInterop
class CodeResponse {}

extension CodeResponseExtension on CodeResponse {
  external String get code;
}

/// Service dedicato alla gestione dell'integrazione con Google Drive.
class GoogleDriveService {
  final FirebaseFunctions _functions;
  final String _googleClientId;
  DateTime? _tokenExpiresAt;
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  GoogleDriveService({
    FirebaseFunctions? functions,
    required String googleClientId,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        _googleClientId = googleClientId;

  /// Controlla se il token è valido localmente, senza chiamare il backend.
  bool _isTokenValid() {
    if (_tokenExpiresAt == null) return false;
    final now = DateTime.now();
    final buffer = const Duration(minutes: 5);
    return _tokenExpiresAt!.isAfter(now.add(buffer));
  }

  /// Assicura che il token di accesso sia valido, rinnovandolo se necessario.
  Future<void> _ensureValidToken() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }
    if (_isTokenValid()) {
      return;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();

    try {
      final callable = _functions.httpsCallable('ensure_valid_drive_token');
      final result = await callable.call<Map<String, dynamic>>({});
      final data = result.data;

      if (data['success'] == true) {
        final expiresIn = data['expiresIn'] as int? ?? 3600;
        _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        _refreshCompleter?.complete();
      } else {
        _tokenExpiresAt = null;
        final error = Exception('Failed to refresh Google Drive token.');
        _refreshCompleter?.completeError(error);
        throw error;
      }
    } catch (e) {
      _tokenExpiresAt = null;
      _refreshCompleter?.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Richiede il permesso per Google Drive usando il flusso server-side.
  Future<bool> requestDrivePermission(String userId) async {
    if (!kIsWeb) {
      throw UnsupportedError('This method is only supported on the web.');
    }

    print('Attempting to request Google Drive permission...');
    print('Using Google Client ID: $_googleClientId');

    if (_googleClientId.isEmpty || _googleClientId == 'your-client-id-here.apps.googleusercontent.com') {
      print('ERROR: Google Client ID is not configured.');
      throw Exception('Google Client ID is not configured. Please check your environment configuration.');
    }

    final completer = Completer<String?>();

    try {
      final JSAny? google = globalContext.getProperty('google'.toJS);
      if (google == null) {
        throw Exception('Google Identity Services library not loaded. Make sure the GSI script is included in index.html');
      }

      final JSAny? accounts = (google as JSObject?)?.getProperty('accounts'.toJS);
      if (accounts == null) {
        throw Exception('Google accounts object not found');
      }

      final GsiAuth2? gsi = (accounts as JSObject?)?.getProperty('oauth2'.toJS) as GsiAuth2?;
      if (gsi == null) {
        throw Exception('Google Identity Services OAuth2 library not found');
      }

      final config = <String, JSAny?>{
        'client_id': _googleClientId.toJS,
        'scope': kDriveScope.toJS,
        'ux_mode': 'popup'.toJS,
        'callback': (CodeResponse response) {
          final code = response.code;
          print('OAuth callback received. Code length: ${code.length}');
          if (code.isNotEmpty) {
            completer.complete(code);
          } else {
            print('OAuth callback received empty code');
            completer.complete(null);
          }
        }.toJS,
        'error_callback': (JSAny error) {
          completer.completeError(Exception('OAuth error: $error'));
        }.toJS,
      }.jsify() as JSObject;

      final client = gsi.initCodeClient(config);
      (client as CodeClient).requestCode();
    } catch (e) {
      print('Error initializing OAuth client: $e');
      return false;
    }

    final authCode = await completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        print('OAuth flow timed out');
        return null;
      },
    );

    if (authCode == null || authCode.isEmpty) {
      print('No authorization code received');
      return false;
    }

    try {
      print('Exchanging authorization code for tokens...');
      final callable = _functions.httpsCallable(
        'exchange_google_auth_code',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call({'code': authCode});
      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        final expiresIn = data['expiresIn'] as int? ?? 3600;
        _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        print('Google Drive connected successfully');
        return true;
      } else {
        print('Token exchange failed: ${data['message'] ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      print('Error exchanging auth code: $e');
      return false;
    }
  }

  /// Carica un file su Google Drive.
  Future<Map<String, dynamic>> uploadFileToDrive({
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/json',
  }) async {
    await _ensureValidToken();
    try {
      final String base64FileData = base64Encode(fileBytes);
      final callable = _functions.httpsCallable(
        'upload_file_to_drive',
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
      };
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' || e.code == 'permission-denied') {
        _tokenExpiresAt = null;
        throw Exception('Google Drive permissions may have been revoked. Please reconnect.');
      }
      throw Exception('Upload error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Revoca i permessi di Google Drive.
  Future<void> revokeDrivePermission(String userId) async {
    try {
      // Revoke via backend
      final callable = _functions.httpsCallable(
        'revoke_google_drive_permission',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      await callable.call({});
      _tokenExpiresAt = null;
    } catch (e) {
      print("Error revoking Drive permission via backend: $e");
      rethrow;
    }
  }
}

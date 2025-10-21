from firebase_functions import https_fn, options, params
from firebase_admin import initialize_app, firestore
from utils import google_oauth
from actions import user_actions
import base64
from datetime import datetime
import os

# Definizione dei segreti da Secret Manager (nuovo sistema)
GOOGLE_CLIENT_ID = params.SecretParam("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = params.SecretParam("GOOGLE_CLIENT_SECRET")

# Inizializza Firebase Admin SDK
initialize_app()


@https_fn.on_call(secrets=[GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET])
def exchange_google_auth_code(req: https_fn.CallableRequest) -> dict:
    """
    Scambia un codice di autorizzazione per un access token e un refresh token.
    Questa funzione viene chiamata dal client dopo che l'utente ha completato il flusso OAuth.
    """
    user_id = req.auth.uid
    if not user_id:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    auth_code = req.data.get('code')
    if not auth_code:
        raise https_fn.HttpsError('invalid-argument', 'Missing authorization code.')

    try:
        return google_oauth.GoogleDriveService.exchange_tokens(user_id, auth_code)
    except Exception as e:
        print(f"Error exchanging tokens for user {user_id}: {e}")
        raise https_fn.HttpsError('internal', f"Failed to exchange tokens: {str(e)}")


@https_fn.on_call()
def ensure_valid_drive_token(req: https_fn.CallableRequest) -> dict:
    """
    Verifica che il token di accesso a Drive sia valido e lo rinnova se necessario.
    Questa funzione viene chiamata dal client prima di ogni operazione su Drive.
    """
    user_id = req.auth.uid
    if not user_id:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    db = firestore.client()
    user_ref = db.collection('users').document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise https_fn.HttpsError('not-found', 'User tokens not found.')

    user_data = user_doc.to_dict()
    expires_at = user_data.get('driveTokenExpiresAt')

    # Se il token è ancora valido (con 5 min di margine), restituisci il tempo rimanente.
    if expires_at:
        remaining = int(expires_at - datetime.now().timestamp())
        if remaining > 300:
            return {'success': True, 'refreshed': False, 'expiresIn': remaining}

    # Altrimenti, rinnova il token.
    try:
        google_oauth.GoogleDriveService.get_valid_credentials(user_id)
        # Dopo il refresh, ricalcola la scadenza.
        updated_doc = user_ref.get()
        new_expires_at = updated_doc.to_dict().get('driveTokenExpiresAt', 0)
        new_remaining = int(new_expires_at - datetime.now().timestamp())

        return {'success': True, 'refreshed': True, 'expiresIn': new_remaining}
    except Exception as e:
        print(f"Error refreshing token for user {user_id}: {e}")
        raise https_fn.HttpsError('permission-denied', f"Failed to refresh token: {str(e)}")


@https_fn.on_call(timeout_sec=60)
def upload_file_to_drive(req: https_fn.CallableRequest) -> dict:
    """
    Carica un file su Google Drive dell'utente autenticato.
    """
    user_id = req.auth.uid
    if not user_id:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    file_name = req.data.get('fileName')
    file_data_base64 = req.data.get('fileData')
    mime_type = req.data.get('mimeType', 'application/octet-stream')

    if not file_name or not file_data_base64:
        raise https_fn.HttpsError('invalid-argument', 'Missing fileName or fileData.')

    try:
        file_data = base64.b64decode(file_data_base64)
    except Exception as e:
        raise https_fn.HttpsError('invalid-argument', f"Invalid base64 data: {str(e)}")

    try:
        return google_oauth.GoogleDriveService.upload_file(user_id, file_name, file_data, mime_type)
    except Exception as e:
        print(f"Error uploading file for user {user_id}: {e}")
        # Se l'errore indica un problema di token, usa un codice di errore specifico.
        if 'token' in str(e).lower() or 'credentials' in str(e).lower():
            raise https_fn.HttpsError('permission-denied', f"Drive permission error: {str(e)}")
        raise https_fn.HttpsError('internal', f"Failed to upload file: {str(e)}")


@https_fn.on_call()
def revoke_google_drive_permission(req: https_fn.CallableRequest) -> dict:
    """
    Revoca i permessi di Google Drive per l'utente.
    """
    user_id = req.auth.uid
    if not user_id:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    try:
        return google_oauth.GoogleDriveService.revoke_tokens(user_id)
    except Exception as e:
        print(f"Error revoking permission for user {user_id}: {e}")
        raise https_fn.HttpsError('internal', f"Failed to revoke permission: {str(e)}")


@https_fn.on_call(timeout_sec=540)
def delete_account_full(req: https_fn.CallableRequest) -> dict:
    """
    Elimina completamente l'account e tutti i dati associati dell'utente autenticato.
    Passi:
    1) Revoca token Google Drive
    2) Elimina progetti pubblici (collection publicProjects)
    3) Elimina dati su Firestore (users/{uid} e sottocollezioni), RTDB (sessions, users), Storage (foto profilo)
    4) Elimina utente da Firebase Auth
    """
    uid = req.auth.uid if req.auth else None
    if not uid:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    # 1) Revoca token Drive (non bloccare il resto in caso di errore)
    try:
        google_oauth.GoogleDriveService.revoke_tokens(uid)
    except Exception as e:
        print(f"[delete_account_full] Warning: revoke_tokens failed for {uid}: {e}")

    # 2) Elimina progetti pubblici
    try:
        user_actions.delete_user_public_projects(uid)
    except user_actions.UserActionException as e:
        print(f"[delete_account_full] Failed to delete public projects for {uid}: {e}")
        raise https_fn.HttpsError('internal', e.args[0])

    # 3-4) Elimina dati Firebase e poi Auth
    try:
        user_actions.delete_firebase_user(uid)
    except user_actions.UserActionException as e:
        print(f"[delete_account_full] Failed during firebase user deletion for {uid}: {e}")
        code = 'internal'
        if e.status_code == 404:
            code = 'not-found'
        raise https_fn.HttpsError(code, e.args[0])
    except Exception as e:
        print(f"[delete_account_full] Unexpected error for {uid}: {e}")
        raise https_fn.HttpsError('internal', 'Unexpected error during account deletion.')

    return {'success': True}


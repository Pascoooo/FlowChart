"""
Modulo per gestire l'integrazione OAuth2 con Google Drive.
"""

import os
from datetime import datetime, timedelta
from typing import Dict, Any

import requests
from google.oauth2.credentials import Credentials
from firebase_admin import firestore

class GoogleDriveService:
    """Gestisce l'integrazione con Google Drive usando OAuth2."""

    @staticmethod
    def exchange_tokens(user_uid: str, auth_code: str, redirect_uri: str) -> Dict[str, Any]:
        """
        Scambia il codice di autorizzazione per un access token e un refresh token.
        """
        client_id = os.environ.get('GOOGLE_CLIENT_ID')
        client_secret = os.environ.get('GOOGLE_CLIENT_SECRET')

        # Log diagnostico sicuro (mascherato): mostra solo prefisso/suffisso del client_id
        if client_id:
            masked = f"{client_id[:8]}...{client_id[-12:]}"
            print(f"[OAuth] Using client_id: {masked}")
        else:
            print("[OAuth] Missing client_id in environment")

        if not client_id or not client_secret:
            raise ValueError("GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set")

        try:
            print(f"Exchanging tokens for user {user_uid}")
            token_url = 'https://oauth2.googleapis.com/token'
            response = requests.post(token_url, data={
                'client_id': client_id,
                'client_secret': client_secret,
                'code': auth_code,
                'grant_type': 'authorization_code',
                'redirect_uri': redirect_uri
            }, timeout=10)

            if response.status_code != 200:
                error_details = response.text
                print(f"Token exchange failed with status {response.status_code}: {error_details}")
                raise Exception(f"Failed to exchange auth code: {error_details}")

            token_data = response.json()
            access_token = token_data.get('access_token')
            refresh_token = token_data.get('refresh_token')
            expires_in = token_data.get('expires_in', 3600)

            if not access_token:
                raise Exception("No access token received from Google")

            expires_at = datetime.now().timestamp() + expires_in

            if not refresh_token:
                # Questo può accadere se l'utente ha già concesso il permesso in passato
                # e non ha revocato l'accesso. In questo caso, salviamo solo il nuovo access token.
                print(f"Warning: No refresh token received for user {user_uid}. User may need to revoke and re-authorize.")

            db = firestore.client()
            user_ref = db.collection('users').document(user_uid)

            token_payload = {
                'driveAccessToken': access_token,
                'driveTokenExpiresAt': expires_at
            }
            if refresh_token:
                token_payload['driveRefreshToken'] = refresh_token

            user_ref.set(token_payload, merge=True)
            print(f"Tokens saved successfully for user {user_uid}")

            return {
                'success': True,
                'message': 'Tokens exchanged and saved successfully.',
                'expiresIn': expires_in
            }

        except requests.RequestException as e:
            print(f"Network error during token exchange: {str(e)}")
            raise Exception(f"Network error during token exchange: {str(e)}")
        except Exception as e:
            print(f"Error during token exchange: {str(e)}")
            raise Exception(f"Error during token exchange: {str(e)}")

    @staticmethod
    def get_valid_credentials(user_uid: str) -> Credentials:
        """
        Recupera le credenziali OAuth2 per l'utente, rinnovandole se necessario.
        """
        client_id = os.environ.get('GOOGLE_CLIENT_ID')
        client_secret = os.environ.get('GOOGLE_CLIENT_SECRET')

        if not client_id or not client_secret:
            raise ValueError("GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be set")

        db = firestore.client()
        user_ref = db.collection('users').document(user_uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise Exception("User tokens not found. Please authorize access to Drive.")

        user_data = user_doc.to_dict()
        access_token = user_data.get('driveAccessToken')
        refresh_token = user_data.get('driveRefreshToken')
        expires_at = user_data.get('driveTokenExpiresAt')

        if not access_token or not refresh_token:
            raise Exception("Missing tokens. Please re-authorize access to Drive.")

        # Se il token è scaduto (con un margine di 5 minuti), rinnovalo.
        if expires_at and datetime.now().timestamp() > (expires_at - 300):
            print(f"Token for user {user_uid} is expired or expiring soon. Refreshing.")
            try:
                token_url = 'https://oauth2.googleapis.com/token'
                response = requests.post(token_url, data={
                    'client_id': client_id,
                    'client_secret': client_secret,
                    'refresh_token': refresh_token,
                    'grant_type': 'refresh_token'
                }, timeout=10)

                if response.status_code != 200:
                    raise Exception(f"Failed to refresh token: {response.text}")

                token_data = response.json()
                access_token = token_data['access_token']
                expires_in = token_data.get('expires_in', 3600)
                new_expires_at = datetime.now().timestamp() + expires_in

                user_ref.update({
                    'driveAccessToken': access_token,
                    'driveTokenExpiresAt': new_expires_at
                })
                print(f"Token for user {user_uid} refreshed successfully.")

            except requests.RequestException as e:
                raise Exception(f"Network error during token refresh: {str(e)}")
            except Exception as e:
                # Se il refresh fallisce (es. refresh token revocato), pulisci i token.
                user_ref.update({
                    'driveAccessToken': firestore.DELETE_FIELD,
                    'driveRefreshToken': firestore.DELETE_FIELD,
                    'driveTokenExpiresAt': firestore.DELETE_FIELD
                })
                raise Exception(f"Failed to refresh token, it might be revoked. Please re-authorize. Error: {str(e)}")

        return Credentials(
            token=access_token,
            refresh_token=refresh_token,
            client_id=client_id,
            token_uri='https://oauth2.googleapis.com/token'
        )

    @staticmethod
    def upload_file(user_uid: str, file_name: str, file_data: bytes, mime_type: str) -> Dict[str, str]:
        """
        Carica un file su Google Drive dell'utente.
        """
        try:
            from googleapiclient.discovery import build
            from googleapiclient.http import MediaInMemoryUpload

            creds = GoogleDriveService.get_valid_credentials(user_uid)
            service = build('drive', 'v3', credentials=creds)

            file_metadata = {'name': file_name}
            media = MediaInMemoryUpload(file_data, mimetype=mime_type, resumable=True)

            file = service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, webViewLink'
            ).execute()

            return {
                'fileId': file.get('id'),
                'webViewLink': file.get('webViewLink')
            }
        except Exception as e:
            raise Exception(f"Error during Drive upload: {str(e)}")

    @staticmethod
    def revoke_tokens(user_uid: str) -> Dict[str, Any]:
        """
        Revoca il refresh token e elimina i dati da Firestore.
        """
        try:
            db = firestore.client()
            user_ref = db.collection('users').document(user_uid)
            user_doc = user_ref.get()

            if user_doc.exists:
                refresh_token = user_doc.to_dict().get('driveRefreshToken')
                if refresh_token:
                    requests.post('https://oauth2.googleapis.com/revoke',
                                  params={'token': refresh_token},
                                  headers={'content-type': 'application/x-www-form-urlencoded'},
                                  timeout=10)
                user_ref.update({
                    'driveAccessToken': firestore.DELETE_FIELD,
                    'driveRefreshToken': firestore.DELETE_FIELD,
                    'driveTokenExpiresAt': firestore.DELETE_FIELD
                })

            return {'success': True, 'message': 'Tokens revoked successfully.'}
        except Exception as e:
            raise Exception(f"Error during token revocation: {str(e)}")

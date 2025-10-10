from firebase_functions import https_fn
from firebase_admin import initialize_app
from utils import security, responses, google_oauth
from actions import user_actions
import json
import base64

initialize_app()

@https_fn.on_request(region='europe-west8')
def deleteUserAuthHttp(req: https_fn.Request) -> https_fn.Response:
    if req.method == 'OPTIONS':
        return responses.handle_options_request()

    try:
        user_uid = security.verify_request(req)
        user_actions.delete_firebase_user(user_uid)
        success_payload = {"message": "User account deleted successfully."}
        return https_fn.Response(
            json.dumps({"data": success_payload}),
            status=200,
            headers=responses.CORS_HEADERS
        )
        # --- FINE CORREZIONE ---

    except security.SecurityException as e:
        # Le risposte di errore non necessitano del campo "data"
        return responses.create_json_response(
            message=str(e),
            status_code=e.status_code
        )
    except user_actions.UserActionException as e:
        return responses.create_json_response(
            message=str(e),
            status_code=e.status_code
        )
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return responses.create_json_response(
            message="An internal error occurred.",
            status_code=500
        )


@https_fn.on_request(region='europe-west8')
def exchangeGoogleTokens(req: https_fn.Request) -> https_fn.Response:
    """
    Scambia i token temporanei di Firebase Auth con token OAuth2 per Google Drive.
    Salva i token in modo sicuro in Firestore.
    """
    if req.method == 'OPTIONS':
        return responses.handle_options_request()

    try:
        user_uid = security.verify_request(req)

        # Estrai i parametri
        request_json = req.get_json()
        data = request_json.get('data', {})
        access_token = data.get('accessToken')
        id_token = data.get('idToken')

        if not access_token or not id_token:
            return responses.create_json_response(
                message="Missing accessToken or idToken parameter",
                status_code=400
            )

        # Scambia i token
        result = google_oauth.GoogleDriveService.exchange_tokens(
            user_uid, access_token, id_token
        )

        return https_fn.Response(
            json.dumps({"data": result}),
            status=200,
            headers=responses.CORS_HEADERS
        )

    except security.SecurityException as e:
        return responses.create_json_response(
            message=str(e),
            status_code=e.status_code
        )
    except Exception as e:
        print(f"Error exchanging tokens: {e}")
        return responses.create_json_response(
            message=f"Failed to exchange tokens: {str(e)}",
            status_code=500
        )


@https_fn.on_request(region='europe-west8')
def uploadFileToDrive(req: https_fn.Request) -> https_fn.Response:
    """
    Carica un file su Google Drive dell'utente autenticato.
    Usa i token salvati in Firestore per autenticarsi con Google.
    """
    if req.method == 'OPTIONS':
        return responses.handle_options_request()

    try:
        user_uid = security.verify_request(req)

        # Estrai i parametri
        request_json = req.get_json()
        data = request_json.get('data', {})
        file_name = data.get('fileName')
        file_data_base64 = data.get('fileData')
        mime_type = data.get('mimeType', 'application/octet-stream')

        if not file_name or not file_data_base64:
            return responses.create_json_response(
                message="Missing fileName or fileData",
                status_code=400
            )

        # Decodifica i dati del file
        try:
            file_data = base64.b64decode(file_data_base64)
        except Exception as e:
            return responses.create_json_response(
                message=f"Invalid base64 data: {str(e)}",
                status_code=400
            )

        # Carica su Drive
        result = google_oauth.GoogleDriveService.upload_file(
            user_uid, file_name, file_data, mime_type
        )

        return https_fn.Response(
            json.dumps({"data": result}),
            status=200,
            headers=responses.CORS_HEADERS
        )

    except security.SecurityException as e:
        return responses.create_json_response(
            message=str(e),
            status_code=e.status_code
        )
    except Exception as e:
        error_msg = str(e)
        print(f"Error uploading file to Drive: {error_msg}")

        # Gestisci errori specifici
        if 'token' in error_msg.lower() or 'scaduto' in error_msg.lower():
            return responses.create_json_response(
                message=error_msg,
                status_code=401  # Unauthorized - richiede riautenticazione
            )

        return responses.create_json_response(
            message=f"Failed to upload file: {error_msg}",
            status_code=500
        )


@https_fn.on_request(region='europe-west8')
def revokeGoogleDrivePermission(req: https_fn.Request) -> https_fn.Response:
    """
    Revoca i permessi di Google Drive eliminando i token salvati.
    """
    if req.method == 'OPTIONS':
        return responses.handle_options_request()

    try:
        user_uid = security.verify_request(req)

        # Elimina i token
        result = google_oauth.GoogleDriveService.revoke_tokens(user_uid)

        return https_fn.Response(
            json.dumps({"data": result}),
            status=200,
            headers=responses.CORS_HEADERS
        )

    except security.SecurityException as e:
        return responses.create_json_response(
            message=str(e),
            status_code=e.status_code
        )
    except Exception as e:
        print(f"Error revoking Drive permission: {e}")
        return responses.create_json_response(
            message=f"Failed to revoke permission: {str(e)}",
            status_code=500
        )

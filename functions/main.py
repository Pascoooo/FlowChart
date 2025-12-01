from firebase_functions import https_fn
from firebase_admin import initialize_app, firestore
from actions import user_actions

# Inizializza Firebase Admin SDK
initialize_app()


@https_fn.on_call(timeout_sec=540)
def delete_account_full(req: https_fn.CallableRequest) -> dict:
    """
    Elimina completamente l'account e tutti i dati associati dell'utente autenticato.
    Passi:
    1) Elimina progetti pubblici (collection publicProjects)
    2) Elimina dati su Firestore (users/{uid} e sottocollezioni), RTDB (sessions, users), Storage (foto profilo)
    3) Elimina utente da Firebase Auth
    """
    uid = req.auth.uid if req.auth else None
    if not uid:
        raise https_fn.HttpsError('unauthenticated', 'User must be authenticated.')

    # 1) Elimina progetti pubblici
    try:
        user_actions.delete_user_public_projects(uid)
    except user_actions.UserActionException as e:
        print(f"[delete_account_full] Failed to delete public projects for {uid}: {e}")
        raise https_fn.HttpsError('internal', e.args[0])

    # 2-3) Elimina dati Firebase (Firestore/RTDB/Storage) e poi Auth
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

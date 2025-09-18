"""
Modulo contenente le azioni logiche per la gestione degli utenti,
da richiamare nelle Cloud Functions.
"""
from firebase_admin import auth, firestore, db, storage

class UserActionException(Exception):
    """Eccezione custom per errori durante le azioni sull'utente."""
    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code

def delete_firebase_user(uid: str) -> None:
    """
    Esegue un'eliminazione a cascata di tutti i dati di un utente
    attraverso i servizi Firebase: Auth, Firestore, RTDB e Storage.
    """
    try:
        print(f"Inizio processo di eliminazione completo per UID: {uid}")

        # 1. Eliminazione file da Firebase Storage
        bucket = storage.bucket()
        profile_pic_blob = bucket.blob(f"profile_pictures/{uid}.jpg")
        if profile_pic_blob.exists():
            profile_pic_blob.delete()
            print(f"Foto profilo per l'utente {uid} eliminata.")

        # 2. Eliminazione dati da Firestore (ricorsiva)
        firestore_client = firestore.client()
        user_doc_ref = firestore_client.collection('users').document(uid)
        firestore_client.recursive_delete(user_doc_ref)
        print(f"Dati Firestore per l'utente {uid} eliminati.")

        # 3. Eliminazione dati da Realtime Database
        db.reference(f'users/{uid}').delete()
        db.reference(f'sessions/{uid}').delete()
        print(f"Dati Realtime Database per l'utente {uid} eliminati.")

        # 4. Eliminazione account da Firebase Authentication (ultimo passo)
        auth.delete_user(uid)
        print(f"Utente {uid} eliminato con successo da Firebase Auth.")

    except auth.UserNotFoundError:
        raise UserActionException(
            message="Utente non trovato in Firebase Authentication.",
            status_code=404
        )
    except Exception as e:
        print(f"Errore imprevisto durante l'eliminazione per l'UID {uid}: {e}")
        raise UserActionException(
            message="Errore interno del server durante l'eliminazione dei dati.",
            status_code=500
        )
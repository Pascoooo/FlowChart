# user_actions.py

from firebase_admin import auth, firestore, db, storage

class UserActionException(Exception):
    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code

def delete_firebase_user(uid: str) -> None:
    try:
        print(f"Inizio processo di eliminazione completo per UID: {uid}")

        # NUOVO: 1. Eliminazione file da Firebase Storage
        bucket = storage.bucket() # Ottiene il bucket di default

        # Elimina la foto profilo (se esiste)
        profile_pic_blob = bucket.blob(f"profile_pictures/{uid}.jpg")
        if profile_pic_blob.exists():
            print(f"Eliminazione foto profilo: {profile_pic_blob.name}")
            profile_pic_blob.delete()
            print(f"Foto profilo per l'utente {uid} eliminata.")

        # Elimina tutti i file in una potenziale cartella utente (es: 'users/uid/')
        # Questo elimina in modo ricorsivo tutti i file e le sottocartelle
        blobs_to_delete = list(bucket.list_blobs(prefix=f"users/{uid}/"))
        if blobs_to_delete:
            print(f"Trovati {len(blobs_to_delete)} file nella cartella 'users/{uid}/'. Inizio eliminazione.")
            for blob in blobs_to_delete:
                blob.delete()
            print(f"Tutti i file nella cartella 'users/{uid}/' sono stati eliminati.")

        # 2. Eliminazione dati da Firestore
        firestore_client = firestore.client()
        user_doc_ref = firestore_client.collection('users').document(uid)

        print(f"Eliminazione ricorsiva del documento Firestore: users/{uid}")
        firestore_client.recursive_delete(user_doc_ref)
        print(f"Dati Firestore per l'utente {uid} eliminati.")

        # 3. Eliminazione dati da Realtime Database
        print(f"Eliminazione dati da Realtime Database: users/{uid}")
        rtdb_ref = db.reference(f'users/{uid}')
        rtdb_ref.delete()
        print(f"Dati Realtime Database per l'utente {uid} eliminati.")

        # 4. Eliminazione account utente da Firebase Authentication (ultimo passo)
        print(f"Eliminazione utente da Firebase Auth: {uid}")
        auth.delete_user(uid)
        print(f"Utente {uid} eliminato con successo da Firebase Auth.")

    except auth.UserNotFoundError:
        raise UserActionException(
            message="User not found in Authentication or has already been deleted.",
            status_code=404
        )
    except Exception as e:
        print(f"Errore durante l'eliminazione completa per l'UID {uid}: {e}")
        raise UserActionException(
            message="An internal error occurred while deleting the user data.",
            status_code=500
        )
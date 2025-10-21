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

def _delete_collection_recursively(coll_ref, batch_size):
    """
    Elimina ricorsivamente tutti i documenti in una collezione e le loro sottocollezioni.
    """
    docs = coll_ref.limit(batch_size).stream()
    deleted = 0

    for doc in docs:
        # Elimina ricorsivamente le sottocollezioni del documento corrente
        for sub_coll in doc.reference.collections():
            _delete_collection_recursively(sub_coll, batch_size)

        # Elimina il documento stesso
        doc.reference.delete()
        deleted += 1

    if deleted >= batch_size:
        _delete_collection_recursively(coll_ref, batch_size)


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

        # 2. CORREZIONE: Eliminazione dati da Firestore (ricorsiva)
        firestore_client = firestore.client()
        user_doc_ref = firestore_client.collection('users').document(uid)

        # Itera ed elimina tutte le sottocollezioni (es. 'projects')
        for coll_ref in user_doc_ref.collections():
            _delete_collection_recursively(coll_ref, 50)

        # Infine, elimina il documento utente principale
        user_doc_ref.delete()
        print(f"Dati Firestore per l'utente {uid} eliminati.")

        # 3. Eliminazione dati da Realtime Database
        db.reference(f'sessions/{uid}').delete()
        # Nota: 'users/{uid}' in RTDB non sembra essere usato dalla tua app,
        # ma lo lascio per sicurezza se hai dati legacy.
        db.reference(f'users/{uid}').delete()
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

def delete_user_public_projects(uid: str) -> None:
    """
    Elimina tutti i progetti pubblici (collection 'publicProjects') di proprietà dell'utente.
    Rimuove anche la sottocollezione 'files' per ogni progetto.
    """
    try:
      firestore_client = firestore.client()
      public_coll = firestore_client.collection('publicProjects')
      query = public_coll.where('ownerId', '==', uid).stream()

      for doc in query:
          # Elimina ricorsivamente eventuali sottocollezioni (es. 'files')
          for sub_coll in doc.reference.collections():
              _delete_collection_recursively(sub_coll, 50)
          # Elimina il documento del progetto pubblico
          doc.reference.delete()
      print(f"Progetti pubblici per l'utente {uid} eliminati.")
    except Exception as e:
      print(f"Errore durante l'eliminazione dei progetti pubblici per {uid}: {e}")
      raise UserActionException(
          message="Impossibile eliminare i progetti pubblici dell'utente.",
          status_code=500
      )

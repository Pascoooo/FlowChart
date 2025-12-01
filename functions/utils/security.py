from firebase_functions import https_fn
from firebase_admin import auth

class SecurityException(Exception):
    def __init__(self, message, status_code):
        super().__init__(message)
        self.status_code = status_code

def verify_request(req: https_fn.Request) -> str:
    if req.method != 'POST':
        raise SecurityException(
            message="Method not allowed.",
            status_code=405
        )

    auth_header = req.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        raise SecurityException(
            message="Unauthorized. Missing authorization token.",
            status_code=401
        )

    id_token = auth_header.split('Bearer ')[1].strip()

    try:
        decoded_token = auth.verify_id_token(id_token)
        user_uid = decoded_token.get('uid')
        if not user_uid:
            raise auth.InvalidIdTokenError("Token is invalid, UID is missing.")
        return user_uid
    except auth.InvalidIdTokenError:
        raise SecurityException(
            message="Authorization token is invalid or has expired.",
            status_code=401
        )
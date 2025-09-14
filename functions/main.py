from firebase_functions import https_fn
from firebase_admin import initialize_app
from utils import security, responses
from actions import user_actions
import json

initialize_app()

@https_fn.on_request(region='europe-west8')
def deleteUserAuthHttp(req: https_fn.Request) -> https_fn.Response:
    if req.method == 'OPTIONS':
        return responses.handle_options_request()

    try:
        user_uid = security.verify_request(req)

        user_actions.delete_firebase_user(user_uid)

        return responses.create_json_response(
            message="User account deleted successfully.",
            status_code=200
        )

    except security.SecurityException as e:
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
from firebase_functions import https_fn
import json

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
}

def handle_options_request() -> https_fn.Response:
    return https_fn.Response(status=204, headers=CORS_HEADERS)

def create_json_response(message: str, status_code: int) -> https_fn.Response:
    return https_fn.Response(
        json.dumps({"message": message}),
        status=status_code,
        headers=CORS_HEADERS
    )
import datetime
import logging
import os

import functions_framework
import google.cloud.logging
import supabase
from flask import Request, Response

log_client = google.cloud.logging.Client()
log_client.setup_logging(
    log_level=logging.INFO, excluded_loggers=("werkzeug",)
)


def _initialize_supabase() -> supabase.Client:
    """Initializes Supabase client."""
    supabase_url = os.environ.get("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_key = os.environ.get("SUPABASE_KEY")
    if not supabase_key:
        raise ValueError("SUPABASE_KEY is not set")

    return supabase.create_client(supabase_url, supabase_key)


def _update_db(uid: str, db: supabase.Client) -> None:
    """Updates last_downloaded in database."""
    try:
        db.table("listen").update({
            "last_downloaded": datetime.datetime.now()
        }).eq("id", uid).execute()
    except supabase.SupabaseException as e:
        logging.error(f"Failed to update database: {e}")


def _download_audio(uid: str, db: supabase.Client) -> bytes | str:
    try:
        response = db.storage.from_("listen").download(uid)
    except supabase.SupabaseException as e:
        logging.error(f"Failed to download audio: {e}")
        return f"Failed to download audio: {e}"

    return response


@functions_framework.http
def download(request: Request) -> Response:
    """Downloads requested audio file from storage."""
    db = _initialize_supabase()
    uid = request.args.get("guid")
    if not uid:
        logging.error(f"No guid provided in {request.args}")
        return Response("No guid provided", status=400)

    audio = _download_audio(uid, db)
    if isinstance(audio, str):
        return Response(audio, status=500)

    _update_db(uid, db)
    return Response(audio, content_type="audio/mpeg", status=200)

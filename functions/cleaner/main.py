import datetime
import logging
import os

import functions_framework
import google.cloud.logging
import supabase

log_client = google.cloud.logging.Client()
log_client.setup_logging(
    log_level=logging.INFO, excluded_loggers=("werkzeug",)
)


def initialize_supabase() -> supabase.Client:
    """Initializes Supabase client."""
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


def _get_expired(
    supabase_client: supabase.Client, cutoff_date: datetime.datetime
) -> list[dict] | None:
    """Gets the ids and num_parts of TTL expired files from Supabase."""
    try:
        response = (
            supabase_client.table("listen")
            .select("guid")
            .lt(
                "last_downloaded",
                cutoff_date,
            )
            .execute()
        )
    except supabase.SupabaseException as e:
        logging.error(f"Failed to fetch data from Supabase: {e}")
        return
    if response and response.count:
        return response.data
    logging.info("No expired files have TTL expired in database")


def _delete_files(
    supabase_client: supabase.Client, ids: list[str], paths: list[str], bucket: str = "listen_tab_podcast"
) -> None:
    try:
        supabase_client.storage.from_(bucket).remove(paths)
    except supabase.StorageException as e:
        logging.error(f"Failed to delete files from Supabase storage: {e}")
        return
    logging.info(f"Deleted {ids} from Supabase storage")


def _build_paths(data: list[dict[str, str]]) -> tuple[list[str], list[str]]:
    """Builds paths for expired files."""
    guids = []
    paths = []

    for datum in data:
        guid = datum["guid"]
        guids.append(guid)
        paths.append(f"{guid}.mp3")

    return guids, paths


@functions_framework.http
def cleaner(request) -> None:
    """Deletes expired files from Supabase storage."""
    days = int(request.args.get("days", 7))
    cutoff_date = datetime.datetime.now() - datetime.timedelta(days=days)
    try:
        supabase_client = initialize_supabase()
    except ValueError as e:
        logging.error(e)
        return

    data = _get_expired(supabase_client, cutoff_date)
    if not data:
        return

    guids, paths = _build_paths(data)
    _delete_files(supabase_client, guids, paths)

import logging
import os
from typing import TypedDict

import functions_framework
import google.cloud.logging
import supabase
from cloudevents.http.event import CloudEvent


log_client = google.cloud.logging.Client()
log_client.setup_logging(
    log_level=logging.INFO, excluded_loggers=("werkzeug",)
)


class Completion(TypedDict):
    uid: str
    audio_url: str


def initialize_subabase() -> supabase.Client:
    """Initializes Supabase client."""
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


@functions_framework.cloud_event
def completed(event: CloudEvent) -> None:
    """Updates audio_url in Supabase."""
    _data = event.get_data()
    if not _data:
        logging.error("Pubsub message is empty")
        return
    data = Completion(**_data)
    supabase_client = initialize_subabase()

    try:
        supabase_client.table("listen").update({
            "audio_url": data["audio_url"]
        }).filter("id", "eq", data["uid"]).execute()
    except supabase.SupabaseException:
        logging.error(f"Failed to update {data['uid']} audio_url")

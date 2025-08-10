import os
import json
import logging
import subprocess
import tempfile
from concurrent.futures import TimeoutError
from typing import TypedDict

import supabase
import functions_framework
import google.cloud.logging
from cloudevents.http.event import CloudEvent
from google.cloud import pubsub_v1


log_client = google.cloud.logging.Client()
log_client.setup_logging(
    log_level=logging.INFO, excluded_loggers=("werkzeug",)
)


class AudioParts(TypedDict):
    uid: str
    num_parts: int


def initialize_publisher() -> tuple[pubsub_v1.PublisherClient, str]:
    """Initializes Cloud Pub/Sub publisher."""
    project_id = os.getenv("GCP_PROJECT", "")
    if not project_id:
        raise ValueError("GCP_PROJECT is not set")
    topic_id = os.getenv("PUBSUB_TOPIC_TTS", "")
    if not topic_id:
        raise ValueError("PUBSUB_TOPIC_TTS is not set")
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, topic_id)
    return publisher, topic_path


def initialize_supabase() -> supabase.Client:
    """Initializes Supabase client."""
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


def _download_audio(
    uid: str, num_parts: int, supabase_client: supabase.Client, tmpdir: str
) -> str | list[str]:
    """Downloads audio parts from Supabase storage."""
    audio_parts = []
    try:
        for i in range(1, num_parts + 1):
            key = f"chunks/{uid}_part_{i:03d}.mp3"
            dest = os.path.join(tmpdir, key)
            bucket = supabase_client.storage.from_("listen")
            if not bucket.exists(key):
                return f"Missing audio part: {key}"

            with open(dest, "wb") as f:
                response = bucket.download(key)
                f.write(response)
            audio_parts.append(dest)
        return audio_parts
    except supabase.StorageException as e:
        return str(e)


def _create_list_file(audio_parts: list[str], tmpdir: str) -> str:
    """Creates a list file for ffmpeg."""
    list_file = os.path.join(tmpdir, "list.txt")
    with open(list_file, "w") as f:
        for part_file in audio_parts:
            f.write(f"file '{part_file}'\n")
    return list_file


def _merge_audio(list_file: str, output_file: str) -> str | None:
    """Merges audio parts into a single file using ffmpeg."""
    cmd = [
        "ffmpeg",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        list_file,
        "-c",
        "copy",
        output_file,
    ]
    try:
        process = subprocess.run(
            cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        if process.stderr:
            raise subprocess.CalledProcessError(
                returncode=1, cmd=cmd, output=process.stderr.decode("utf-8")
            )
        return
    except subprocess.CalledProcessError as e:
        return str(e)


def _upload_file(
    filename: str, path: str, supabase_client: supabase.Client
) -> str | None:
    """Uploads a file to Supabase storage."""
    try:
        bucket = supabase_client.storage.from_("listen")
        bucket.upload(filename, path)
        return
    except supabase.StorageException as e:
        return str(e)


def _start_merge(
    audio_parts: list[str], tmpdir: str, output_file: str
) -> str | None:
    """Merges audio parts into a single file."""
    list_file = _create_list_file(audio_parts, tmpdir)
    error = _merge_audio(list_file, output_file)
    if error:
        return error


def _publish_notification(
    uid: str,
    filename: str,
    publisher: pubsub_v1.PublisherClient,
    topic_path: str,
) -> None:
    """Publishes a message to a Cloud Pub/Sub topic."""
    data = {
        "id": uid,
        "finalized_file": filename,
    }
    data = json.dumps(data).encode("utf-8")
    try:
        future = publisher.publish(topic_path, data=data)
        future.result()
    except (RuntimeError, TimeoutError, ValueError) as e:
        logging.error(f"Failed to publish: {e}")


@functions_framework.cloud_event
def merge(cloud_event: CloudEvent) -> None:
    """Merges audio parts into a single file."""
    _data = cloud_event.get_data()
    if not _data:
        logging.error("No data in CloudEvent")
        return
    data = AudioParts(**_data)
    uid: str = data["uid"]
    num_parts = data["num_parts"]

    publisher, topic_path = initialize_publisher()
    supabase_client = initialize_supabase()
    tmpdir = tempfile.mkdtemp()

    error_or_audio_parts: str | list[str] = _download_audio(
        uid, num_parts, supabase_client, tmpdir
    )
    if isinstance(error_or_audio_parts, str):
        error = error_or_audio_parts
        logging.error(error)
        return

    audio_parts = error_or_audio_parts
    if len(audio_parts) >= 1:
        output_file = os.path.join(tmpdir, f"{uid}.mp3")
        merge_error = _start_merge(audio_parts, tmpdir, output_file)
        if merge_error:
            logging.error(merge_error)
            return None
    else:
        output_file = os.path.join(tmpdir, audio_parts[0])

    finalized_file = f"complete/{uid}.mp3"
    upload_error = _upload_file(finalized_file, output_file, supabase_client)
    if upload_error:
        logging.error(upload_error)
        return

    _publish_notification(uid, finalized_file, publisher, topic_path)

import datetime
import logging
import os
import tempfile

import functions_framework
import google.cloud.logging
import supabase
from cloudevents.http.event import CloudEvent

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


def _get_current_period() -> tuple[str, str]:
    """Gets current month and year as strings."""
    now = datetime.datetime.now()
    return now.strftime("%B"), now.strftime("%Y")


def _get_character_count(
    count: int,
    current_month: str,
    current_year: str,
    db: supabase.Client,
    table: str,
) -> int | None:
    try:
        response = (
            db.table(table)
            .select("count")
            .match({
                "month": current_month,
                "year": current_year,
            })
            .execute()
        )
        if response and response.count:
            return response.data[0]["count"]
        return 0
    except supabase.SupabaseException as e:
        logging.error(f"Failed to insert data into Supabase: {e}")
        return None


def _update_character_count(
    count: int,
    current_month: str,
    current_year: str,
    db: supabase.Client,
    table: str,
) -> bool:
    try:
        db.table(table).upsert({
            "count": count,
            "month": current_month,
            "year": current_year,
        }).execute()
        return True
    except supabase.SupabaseException as e:
        logging.error(f"Failed to update data in Supabase: {e}")
        return False


def _add_character_count(
    text: str,
    db: supabase.Client,
    table: str = "character_count",
    max_count: int = 4_000_000,
) -> bool:
    text_length = len(text)

    current_month, current_year = _get_current_period()

    count = _get_character_count(
        text_length, current_month, current_year, db, table
    )
    if count is None:
        return False

    count += text_length

    updated = _update_character_count(
        count, current_month, current_year, db, table
    )
    if not updated:
        return False

    return count < max_count


def _update_db(
    guid: str, file_url: str, db: supabase.Client, table: str = "listen"
) -> None:
    """Updates audio_url in Supabase."""
    try:
        db.table(table).update({"audio_url": file_url}).eq(
            "guid", guid
        ).execute()
    except supabase.SupabaseException:
        logging.error(f"Failed to update {guid} audio_url")


def _upload_audio(
    guid: str, audio_file: str, db: supabase.Client, bucket: str = "listen"
) -> None:
    """Uploads audio to storage bucket."""
    try:
        with open(audio_file, "rb") as f:
            db.storage.from_(bucket).upload(file=f, path=f"{guid}.mp3")
    except supabase.SupabaseException as e:
        logging.error(f"Failed to upload audio: {e}")


def _create_temp_audio_file(guid: str) -> str:
    """Creates a temporary audio file path."""
    tempdir = tempfile.mkdtemp()
    return os.path.join(tempdir, f"{guid}.mp3")


def _write_audio_file(audio_content: bytes, audio_file: str) -> None:
    """Writes audio content to file."""
    with open(audio_file, "wb") as f:
        f.write(audio_content)


def _generate_cloud_tts_audio(text: str, guid: str) -> str | None:
    """Generates audio using Google Cloud Text-to-Speech API."""
    from google.cloud import texttospeech
    from google.api_core.exceptions import GoogleAPIError

    input = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(
        language_code="en-US", name="en-US-Standard-H"
    )
    config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    client = texttospeech.TextToSpeechClient()
    try:
        response = client.synthesize_speech(
            input=input, voice=voice, audio_config=config
        )
    except GoogleAPIError as e:
        logging.error(f"Failed to generate audio with Cloud TTS: {e}")
        return None

    if not response.audio_content:
        return None

    audio_file = _create_temp_audio_file(guid)
    _write_audio_file(response.audio_content, audio_file)
    return audio_file


def _generate_gtts_audio(text: str, guid: str) -> str | None:
    """Generates audio using gTTS."""
    import gtts

    audio_file = _create_temp_audio_file(guid)
    tts = gtts.gTTS(text, lang="en")
    try:
        tts.save(audio_file)
        return audio_file
    except gtts.gTTSError as e:
        logging.error(f"Failed to generate audio with gTTS: {e}")
        return None


def _generate_audio(text: str, guid: str, use_cloud_tts: bool) -> str | None:
    """Generates audio using the appropriate TTS service."""
    if use_cloud_tts:
        logging.info("Using Google Cloud TTS")
        return _generate_cloud_tts_audio(text, guid)
    else:
        logging.info("Character count limit reached. Using gTTS")
        return _generate_gtts_audio(text, guid)


@functions_framework.cloud_event
def tts(event: CloudEvent) -> None:
    """Generates audio from text using Text-to-Speech API."""
    data = event.get_data()
    if not data:
        logging.error("No data in CloudEvent")
        return

    guid = data["guid"]
    text = data["text"]

    supabase_client = _initialize_supabase()
    use_cloud_tts = _add_character_count(text, supabase_client)

    audio_file = _generate_audio(text, guid, use_cloud_tts)
    if not audio_file:
        logging.error("Failed to generate audio")
        return

    _upload_audio(guid, audio_file, supabase_client)
    _update_db(guid, audio_file, supabase_client)

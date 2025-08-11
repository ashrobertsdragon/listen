import datetime
import os
import re
import json
import uuid
from typing import TypedDict

import functions_framework
import justext
import supabase
from flask import jsonify, Request, Response
from google.cloud import pubsub_v1


class Page(TypedDict):
    url: str
    html: str


def _get_paragraphs(html: str) -> list[str]:
    """Get paragraphs from HTML body."""
    return justext.justext(html, justext.get_stoplist("English"))


def _get_title(html: str) -> str:
    """Get title from page HTML."""
    match = re.search(
        r"<title>(.*?)</title>", html, re.MULTILINE | re.IGNORECASE
    )
    return match.group(1).strip() if match else "Untitled"


def _publish_notification(
    guid: str,
    url: str,
    title: str,
    paragraphs: list[str],
    publisher: pubsub_v1.PublisherClient,
    topic_path: str,
) -> None:
    """Publishes a message to a Cloud Pub/Sub topic."""
    data = {
        "guid": guid,
        "url": url,
        "title": title,
        "paragraphs": paragraphs,
    }
    data = json.dumps(data).encode("utf-8")
    future = publisher.publish(topic_path, data=data)
    future.result()


def _save_to_supabase(
    guid: str,
    url: str,
    title: str,
    supabase_client: supabase.Client,
) -> None:
    """Saves data to Supabase."""
    supabase_client.table("listen").insert({
        "guid": guid,
        "url": url,
        "title": title,
        "created_at": datetime.datetime.now(),
    })


def parse(
    url: str,
    html: str,
    publisher: pubsub_v1.PublisherClient,
    topic_path: str,
    supabase_client: supabase.Client,
) -> bool:
    """Parses HTML and sends notification to Cloud Pub/Sub."""
    if not url or not html:
        return False

    paragraphs = _get_paragraphs(html)
    if not paragraphs:
        return False

    title = _get_title(html)

    guid = str(uuid.uuid4())

    _publish_notification(guid, url, title, paragraphs, publisher, topic_path)
    _save_to_supabase(guid, url, title, supabase_client)
    return True


def initialize_pubsub() -> tuple[pubsub_v1.PublisherClient, str]:
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


def initialize_subabase() -> supabase.Client:
    """Initializes Supabase client."""
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


@functions_framework.errorhandler(Exception)
def handle_error(error: Exception) -> Response:
    return jsonify({"error": f"{str(error)}", "status": 500})


@functions_framework.http
def upload(page: Request) -> Response:
    """Parses HTML and sends notification to Cloud Pub/Sub."""
    data: Page = page.get_json(force=True)
    url = data["url"]
    html = data["html"]

    publisher, topic_path = initialize_pubsub()
    supabase_client = initialize_subabase()

    result = parse(url, html, publisher, topic_path, supabase_client)

    if not result:
        return jsonify({"error": "Upload failed", "status": 400})
    return jsonify({"message": "Success", "status": 204})

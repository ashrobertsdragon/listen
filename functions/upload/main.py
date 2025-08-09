import datetime
import os
import re
import json
import uuid
from concurrent.futures import TimeoutError
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
    return justext.justext(html, justext.get_stoplist("English"))


def _get_title(html: str) -> str:
    match = re.search(
        r"<title>(.*?)</title>", html, re.MULTILINE | re.IGNORECASE
    )
    return match.group(1).strip() if match else "Untitled"


def _publish_notification(
    uid: str,
    url: str,
    title: str,
    paragraphs: list[str],
    publisher: pubsub_v1.PublisherClient,
    topic_path: str,
) -> None:
    data = {
        "id": uid,
        "url": url,
        "title": title,
        "paragraphs": paragraphs,
    }
    data = json.dumps(data).encode("utf-8")
    future = publisher.publish(topic_path, data=data)
    future.result()


def _save_to_supabase(
    uid: str,
    url: str,
    title: str,
    supabase_client: supabase.Client,
) -> None:
    supabase_client.table("listen").insert({
        "id": uid,
        "url": url,
        "title": title,
        "created_at": datetime.datetime.now(),
    })


def main(
    url: str,
    html: str,
    publisher: pubsub_v1.PublisherClient,
    topic_path: str,
    supabase_client: supabase.Client,
) -> Exception | bool:
    if not url or not html:
        return False

    paragraphs = _get_paragraphs(html)
    if not paragraphs:
        return False

    title = _get_title(html)

    uid = str(uuid.uuid4())

    try:
        _publish_notification(
            uid, url, title, paragraphs, publisher, topic_path
        )
        _save_to_supabase(uid, url, title, supabase_client)
        return True
    except (
        RuntimeError,
        TimeoutError,
        ValueError,
        supabase.SupabaseException,
    ) as e:
        return e


def initialize_pubsub() -> tuple[pubsub_v1.PublisherClient, str]:
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
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


@functions_framework.http
def upload(page: Request) -> Response:
    data: Page = page.get_json(force=True)
    url = data["url"]
    html = data["html"]

    publisher, topic_path = initialize_pubsub()
    supabase_client = initialize_subabase()

    result = main(url, html, publisher, topic_path, supabase_client)

    if isinstance(result, Exception):
        return jsonify({"message": f"Failed: {str(result)}", "status": 500})
    if not result:
        return jsonify({"message": "Failed", "status": 400})
    return jsonify({"message": "Success", "status": 204})

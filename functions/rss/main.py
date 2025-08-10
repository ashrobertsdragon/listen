import os
import logging
import tempfile
import textwrap

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
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


def _get_audio_urls(
    supabase_client: supabase.Client,
) -> list[dict[str, str]]:
    """Gets audio URLs from Supabase."""
    try:
        response = (
            supabase_client.table("listen")
            .select("title, created_at, id, audio_url")
            .not_.is_("audio_url", "null")
            .execute()
        )
    except supabase.SupabaseException as e:
        logging.error(f"Failed to fetch data from Supabase: {e}")
        return []
    if not response or not response.count:
        logging.info("No audio URLs found in database")
        return []
    return response.data


def _build_rss_feed(data: list[dict[str, str]]) -> str:
    """Builds RSS feed."""
    xml = [
        textwrap.dedent(f"""\
        <item>
          <title>{datum["title"]}</title>
          <enclosure url="{datum["audio_url"]}" type="audio/mpeg" />
          <guid>{datum["id"]}</guid>
          <pubDate>{datum["created_at"]}</pubDate>
        </item>
        """)
        for datum in data
    ]
    items = "\n".join(xml)

    return textwrap.dedent(f"""\
        <?xml version="1.0" encoding="utf-8"?>
          <rss version="2.0">
            <channel>
              <title>Personal Podcast</title>
                {items}
            </channel>
          </rss>
    """)


def _save_rss_feed(rss_feed: str) -> str:
    """Saves RSS feed to a temporary file."""
    tempdir = tempfile.mkdtemp()
    rss_file = os.path.join(tempdir, "rss.xml")
    with open(rss_file, "w") as f:
        f.write(rss_feed)
    return rss_file


@functions_framework.http
def rss(_: Request) -> Response:
    """Sends RSS feed to client."""
    supabase_client = _initialize_supabase()

    data = _get_audio_urls(supabase_client)
    rss_feed = _build_rss_feed(data)
    rss_file = _save_rss_feed(rss_feed)

    return Response(
        rss_file,
        status=200,
        mimetype="text/xml",
        content_type="application/rss+xml",
    )

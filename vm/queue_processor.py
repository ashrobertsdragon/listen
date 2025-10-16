import json
import os
import time
from datetime import datetime

import requests
import websocket

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
UPLOAD_ENDPOINT = os.environ["UPLOAD_ENDPOINT"]
CHROME_DEBUG_PORT = 9222


def get_pending_url():
    response = requests.get(
        f"{SUPABASE_URL}url_queue",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
        },
        params={"status": "eq.pending", "order": "created_at.asc", "limit": 1},
    )
    response.raise_for_status()
    urls = response.json()
    return urls[0] if urls else None


def mark_processing(url_id):
    requests.patch(
        f"{SUPABASE_URL}url_queue",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
        },
        params={"id": f"eq.{url_id}"},
        json={"status": "processing"},
    )


def mark_completed(url_id):
    requests.patch(
        f"{SUPABASE_URL}url_queue",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
        },
        params={"id": f"eq.{url_id}"},
        json={
            "status": "completed",
            "processed_at": datetime.utcnow().isoformat(),
        },
    )


def mark_failed(url_id, error):
    requests.patch(
        f"{SUPABASE_URL}url_queue",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
        },
        params={"id": f"eq.{url_id}"},
        json={
            "status": "failed",
            "error_message": str(error),
            "processed_at": datetime.utcnow().isoformat(),
        },
    )


def create_tab_and_get_html(url):
    response = requests.put(f"http://localhost:{CHROME_DEBUG_PORT}/json/new")
    response.raise_for_status()
    tab = response.json()

    ws = websocket.create_connection(tab["webSocketDebuggerUrl"])

    ws.send(
        json.dumps(
            {"id": 1, "method": "Page.navigate", "params": {"url": url}}
        )
    )
    ws.recv()

    time.sleep(3)

    ws.send(
        json.dumps(
            {
                "id": 2,
                "method": "Runtime.evaluate",
                "params": {
                    "expression": "document.documentElement.outerHTML",
                    "returnByValue": True,
                },
            }
        )
    )

    result = json.loads(ws.recv())
    html = result["result"]["result"]["value"]
    ws.close()

    requests.get(
        f"http://localhost:{CHROME_DEBUG_PORT}/json/close/{tab['id']}"
    )

    return html


def process_url(url_record):
    url_id = url_record["id"]
    url = url_record["url"]

    print(f"Processing: {url}")
    mark_processing(url_id)

    try:
        html = create_tab_and_get_html(url)

        response = requests.post(
            UPLOAD_ENDPOINT,
            json={"url": url, "html": html},
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()

        mark_completed(url_id)
        print(f"Completed: {url}")

    except Exception as e:
        print(f"Failed: {url} - {e}")
        mark_failed(url_id, str(e))


def main():
    print("Queue processor started")
    while True:
        try:
            url_record = get_pending_url()
            if url_record:
                process_url(url_record)
                time.sleep(2)
            else:
                time.sleep(10)
        except KeyboardInterrupt:
            print("Shutting down")
            break
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(10)


if __name__ == "__main__":
    main()

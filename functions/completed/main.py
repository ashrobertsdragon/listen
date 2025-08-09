import os
from typing import TypedDict

import functions_framework
import supabase
from flask import jsonify, Request, Response


class Completion(TypedDict):
    uid: str
    audio_url: str


def initialize_subabase() -> supabase.Client:
    supabase_url = os.getenv("SUPABASE_URL")
    if not supabase_url:
        raise ValueError("SUPABASE_URL is not set")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    if not supabase_service_key:
        raise ValueError("SUPABASE_SERVICE_KEY is not set")
    return supabase.create_client(supabase_url, supabase_service_key)


@functions_framework.http
def completed(request: Request) -> Response:
    data: Completion = request.get_json(force=True)
    supabase_client = initialize_subabase()

    try:
        supabase_client.table("listen").update({
            "audio_url": data["audio_url"]
        }).filter("id", "eq", data["uid"]).execute()
        return jsonify({"message": "Success", "status": 204})
    except supabase.SupabaseException:
        return jsonify({"message": "Failed", "status": 500})

locals {
  function_configs = {
    download = { memory = 256, timeout = 60 }
    upload   = { memory = 512, timeout = 120 }
    rss      = { memory = 256, timeout = 30 }
    cleaner  = { memory = 256, timeout = 300 }
    tts      = { memory = 512, timeout = 540 }
  }
}



resource "google_storage_bucket" "functions_bucket" {
  name                        = "${var.project_id}-functions-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "function_zip" {
  for_each    = toset(concat(var.function_names_http, ["tts"]))
  type        = "zip"
  source_dir  = "${path.root}/../functions/${each.value}"
  output_path = "${path.module}/tmp/${each.value}.zip"
}

resource "google_storage_bucket_object" "function_object" {
  for_each = toset(concat(var.function_names_http, ["tts"]))
  name     = "${each.value}-source-${data.archive_file.function_zip[each.value].output_md5}.zip"
  bucket   = google_storage_bucket.functions_bucket.name
  source   = data.archive_file.function_zip[each.value].output_path
}

resource "google_pubsub_topic" "tts_topic" {
  name = "tts-topic"
}

resource "google_cloudfunctions_function" "http_functions" {
  for_each              = toset(var.function_names_http)
  name                  = each.value
  runtime               = var.runtime
  entry_point           = "main"
  service_account_email = var.functions_sa_email
  source_archive_bucket = google_storage_bucket.functions_bucket.name
  source_archive_object = google_storage_bucket_object.function_object[each.value].name
  trigger_http          = true
  available_memory_mb   = local.function_configs[each.value].memory
  timeout               = local.function_configs[each.value].timeout

  environment_variables = {
    SUPABASE_URL         = var.supabase_url
    SUPABASE_KEY         = var.supabase_key 
    GCP_PROJECT          = var.project_id
    PUBSUB_TOPIC_TTS     = google_pubsub_topic.tts_topic.name
  }

  depends_on = [google_storage_bucket_object.function_object]
}

resource "google_cloudfunctions_function" "tts_function" {
  name                  = "tts"
  runtime               = var.runtime
  entry_point           = "main"
  service_account_email = var.functions_sa_email
  source_archive_bucket = google_storage_bucket.functions_bucket.name
  source_archive_object = google_storage_bucket_object.function_object["tts"].name
  available_memory_mb   = local.function_configs["tts"].memory
  timeout               = local.function_configs["tts"].timeout

  environment_variables = {
    SUPABASE_URL = var.supabase_url
    SUPABASE_KEY = var.supabase_key
  }

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.tts_topic.name
  }

  depends_on = [google_storage_bucket_object.function_object]
}

resource "google_cloud_scheduler_job" "cleaner_job" {
  name      = "trigger-cleaner"
  schedule  = "0 0 */7 * *"
  time_zone = "UTC"

  http_target {
    uri         = google_cloudfunctions_function.http_functions["cleaner"].https_trigger_url
    http_method = "GET"
    oidc_token {
      service_account_email = var.scheduler_sa_email
    }
  }
}
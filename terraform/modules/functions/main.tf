resource "google_cloudfunctions_function" "http_functions" {
  for_each              = toset(var.function_names_http)
  name                  = each.value
  runtime               = "python310"
  entry_point           = "main"
  service_account_email = var.functions_sa_email
  source_archive_bucket = google_storage_bucket.functions_bucket.name
  source_archive_object = google_storage_bucket_object.function_object[each.value].name
  trigger_http          = true
}

resource "google_cloudfunctions_function" "tts_function" {
  name                  = "tts"
  runtime               = "python310"
  entry_point           = "main"
  service_account_email = var.functions_sa_email
  source_archive_bucket = google_storage_bucket.functions_bucket.name
  source_archive_object = google_storage_bucket_object.function_object["tts"].name

  event_trigger {
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    resource   = google_pubsub_topic.tts_topic.name
  }
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

output "upload_function_url" {
  value = google_cloudfunctions_function.http_functions["upload"].https_trigger_url
}

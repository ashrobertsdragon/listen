locals {
  function_configs = {
    download = { memory = "256Mi", timeout = 60 }
    upload   = { memory = "512Mi", timeout = 120 }
    rss      = { memory = "256Mi", timeout = 30 }
    cleaner  = { memory = "256Mi", timeout = 300 }
    tts      = { memory = "512Mi", timeout = 540 }
  }

  function_hashes = {
    for f in concat(var.function_names_http, ["tts"]) :
    f => md5(join("", [
      for p in fileset("${path.root}/../functions/${f}", "**") :
      filemd5("${path.root}/../functions/${f}/${p}")
    ]))
  }
}

resource "google_storage_bucket" "functions_bucket" {
  name                        = "${var.project_id}-functions-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "archive_file" "function_zip" {
  for_each    = toset(concat(var.function_names_http, ["tts"]))
  type        = "zip"
  source_dir  = "${path.root}/../functions/${each.value}"
  excludes = ["${path.root}/../functions/${each.value}/pyproject.toml"]
  output_path = "${path.module}/tmp/${each.value}-${local.function_hashes[each.value]}.zip"
}

resource "google_storage_bucket_object" "function_object" {
  for_each = toset(concat(var.function_names_http, ["tts"]))
  name     = "${each.value}-source-${local.function_hashes[each.value]}.zip"
  bucket   = google_storage_bucket.functions_bucket.name
  source   = data.archive_file.function_zip[each.value].output_path
}

resource "google_pubsub_topic" "tts_topic" {
  name = "tts-topic"
}

resource "google_cloudfunctions2_function" "http_functions" {
  for_each = toset(var.function_names_http)
  name     = each.value
  location = var.region

  build_config {
    runtime     = var.runtime
    entry_point = "main"
    service_account = "projects/${var.project_id}/serviceAccounts/${var.functions_sa_email}"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_bucket.name
        object = google_storage_bucket_object.function_object[each.value].name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = local.function_configs[each.value].memory
    timeout_seconds       = local.function_configs[each.value].timeout
    service_account_email = var.functions_sa_email
    environment_variables = {
      SUPABASE_URL      = var.supabase_url
      SUPABASE_KEY      = var.supabase_key
      GCP_PROJECT       = var.project_id
      PUBSUB_TOPIC_TTS  = google_pubsub_topic.tts_topic.name
    }
  }

  depends_on = [ google_storage_bucket_object.function_object ]
}

resource "google_cloudfunctions2_function" "tts_function" {
  name     = "tts"
  location = var.region

  build_config {
    runtime     = var.runtime
    entry_point = "main"
    service_account = "projects/${var.project_id}/serviceAccounts/${var.functions_sa_email}"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_bucket.name
        object = google_storage_bucket_object.function_object["tts"].name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    available_memory      = local.function_configs["tts"].memory
    timeout_seconds       = local.function_configs["tts"].timeout
    service_account_email = var.functions_sa_email
    environment_variables = {
      SUPABASE_URL = var.supabase_url
      SUPABASE_KEY = var.supabase_key
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.tts_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }

  depends_on = [ google_storage_bucket_object.function_object ]
}

resource "google_cloud_scheduler_job" "cleaner_job" {
  name      = "cleaner-trigger"
  schedule  = "0 0 */7 * *"
  time_zone = "UTC"

  http_target {
    uri         = google_cloudfunctions2_function.http_functions["cleaner"].url
    http_method = "GET"
    oidc_token {
      service_account_email = var.scheduler_sa_email
    }
  }
}

resource "null_resource" "cleanup_tmp_files" {
  depends_on = [ google_storage_bucket_object.function_object ]

triggers = {
  functions_hash = local.function_hashes
}

  provisioner "local-exec" {
    command = var.windows ? "Remove-Item ${path.module}/tmp -Recurse -Force" : "rm -rf ${path.module}/tmp && rmdir ${path.module}/tmp"
  }
}
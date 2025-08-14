output "upload_function_url" {
  value = google_cloudfunctions_function.http_functions["upload"].https_trigger_url
}

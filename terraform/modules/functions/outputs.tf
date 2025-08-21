output "upload_function_url" {
  value = google_cloudfunctions2_function.http_functions["upload"].url
}

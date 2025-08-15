variable "project_id" {}

resource "google_service_account" "functions_sa" {
  account_id   = "functions-sa"
  display_name = "Service Account for Cloud Functions"
}

resource "google_project_iam_member" "functions_roles" {
  for_each = toset([
    "roles/cloudfunctions.invoker",
    "roles/pubsub.publisher",
    "roles/storage.objectViewer"
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.functions_sa.email}"
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "scheduler-sa"
  display_name = "Service Account for Cloud Scheduler"
}

resource "google_project_iam_member" "scheduler_roles" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

output "functions_service_account_email" {
  value = google_service_account.functions_sa.email
}

output "scheduler_service_account_email" {
  value = google_service_account.scheduler_sa.email
}

resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway-sa"
  display_name = "Service Account for API Gateway"
}

resource "google_project_iam_member" "api_gateway_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.api_gateway_sa.email}"
}

output "api_gateway_service_account_email" {
  value = google_service_account.api_gateway_sa.email
}
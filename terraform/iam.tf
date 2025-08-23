resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "servicemanagement.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "apikeys.googleapis.com",
    "apigateway.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])
  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

resource "google_service_account" "functions_sa" {
  account_id   = "functions-sa"
  display_name = "Service Account for Cloud Functions"

  depends_on   = [google_project_service.required_apis]
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "scheduler-sa"
  display_name = "Service Account for Cloud Scheduler"

  depends_on   = [google_project_service.required_apis]
}

resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway-sa"
  display_name = "Service Account for API Gateway"

  depends_on   = [google_project_service.required_apis]
}

resource "google_project_iam_member" "functions_roles" {
  for_each = toset([
    "roles/cloudfunctions.developer",
    "roles/pubsub.publisher",
    "roles/storage.objectCreator",
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/artifactregistry.reader",
    "roles/artifactregistry.writer",
    "roles/run.admin",
    "roles/iam.serviceAccountUser" 
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.functions_sa.email}"
}


resource "google_project_iam_member" "scheduler_roles" {
  for_each = toset([
    "roles/cloudfunctions.invoker",
    "roles/pubsub.publisher"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

resource "google_project_iam_member" "api_gateway_roles" {
  for_each = toset([
    "roles/cloudfunctions.invoker",
    "roles/run.invoker"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.api_gateway_sa.email}"
}

output "functions_service_account_email" {
  value = google_service_account.functions_sa.email
}

output "scheduler_service_account_email" {
  value = google_service_account.scheduler_sa.email
}

output "api_gateway_service_account_email" {
  value = google_service_account.api_gateway_sa.email
}

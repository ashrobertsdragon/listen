locals {
  functions_sa_permissions = [
    "roles/pubsub.publisher",
    "roles/logging.logWriter",
  ]
}

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

  depends_on = [google_project_service.required_apis]
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "scheduler-sa"
  display_name = "Service Account for Cloud Scheduler"

  depends_on = [google_project_service.required_apis]
}

resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway-sa"
  display_name = "Service Account for API Gateway"

  depends_on = [google_project_service.required_apis]
}

resource "google_project_iam_member" "functions_roles" {
  for_each = toset(local.functions_sa_permissions)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.functions_sa.email}"
}


resource "google_project_iam_member" "scheduler_roles" {
  for_each = toset([
    "roles/cloudfunctions.invoker",
    "roles/pubsub.publisher",
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

data "google_project" "project" {
  project_id = var.project_id
}

resource "google_project_iam_member" "cloudbuild_sa_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_project_service.required_apis]
}

resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    google_project_iam_member.functions_roles,
    google_project_iam_member.cloudbuild_sa_storage,
    google_service_account.functions_sa
  ]

  create_duration = "30s"

  triggers = {
    functions_sa       = google_service_account.functions_sa.email
    cloudbuild_sa      = "${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
    project_id         = var.project_id
    roles              = jsonencode(local.functions_sa_permissions)
  }
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

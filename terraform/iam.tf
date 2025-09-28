locals {
  functions_sa_permissions = [
    "roles/cloudfunctions.developer",
    "roles/pubsub.publisher",
    "roles/storage.objectCreator",
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/artifactregistry.reader",
    "roles/artifactregistry.writer",
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/cloudbuild.builds.editor",
    "roles/storage.objectAdmin"
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

resource "time_sleep" "wait_for_iam_propagation" {
  depends_on = [
    google_project_iam_member.functions_roles,
    google_service_account.functions_sa
  ]

  create_duration = "30s"
}

data "google_service_account_iam_policy" "functions_sa_policy" {
  service_account_id = google_service_account.functions_sa.name

  depends_on = [time_sleep.wait_for_iam_propagation]
}

locals {
  required_roles = join(" ", local.functions_sa_permissions)

}

resource "terraform_data" "validate_functions_iam" {
  depends_on = [time_sleep.wait_for_iam_propagation]

  provisioner "local-exec" {
    command = "${local.is_windows ? "python" : "python3"} ${path.module}/check_gcloud.py ${var.project_id} ${google_service_account.functions_sa.email} ${local.required_roles}"
  }

  triggers_replace = [
    google_service_account.functions_sa.email,
    local.functions_sa_permissions
  ]
}

resource "terraform_data" "functions_iam_ready" {
  depends_on = [terraform_data.validate_functions_iam]

  triggers_replace = [
    google_service_account.functions_sa.email,
    local.functions_sa_permissions
  ]
  input = { "ready" = terraform_data.validate_functions_iam.id }
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

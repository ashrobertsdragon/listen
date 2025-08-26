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
    "roles/iam.serviceAccountUser"
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

  depends_on   = [ google_project_service.required_apis ]
}

resource "google_service_account" "scheduler_sa" {
  account_id   = "scheduler-sa"
  display_name = "Service Account for Cloud Scheduler"

  depends_on   = [ google_project_service.required_apis ]
}

resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway-sa"
  display_name = "Service Account for API Gateway"

  depends_on   = [ google_project_service.required_apis ]
}

resource "google_project_iam_member"  "functions_roles" {
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

locals {
  required_roles = join(" ", local.functions_sa_permissions)

  batch_script = <<EOT
  @echo off
  setlocal enabledelayedexpansion
  set "TEMP_ROLES_FILE=%TEMP%\tf_roles_%RANDOM%.txt"

  :loop
  if exist "%TEMP_ROLES_FILE%" del /q "%TEMP_ROLES_FILE%" 2>nul

  gcloud projects get-iam-policy ${var.project_id} ^
    --flatten="bindings[].members" ^
    --format="value(bindings[].role)" ^
    --filter="bindings.members:serviceAccount:${google_service_account.functions_sa.email}" ^
    > "%TEMP_ROLES_FILE%" 2>nul

  set missing=0
  for %%r in (${local.required_roles}) do (
    findstr /x "%%r" roles.txt >nul
    if errorlevel 1 (
      set missing=1
      goto :checkdone
    )
  )

  :checkdone
  if %missing%==0 (
    goto :end
  )

  timeout /t 5 >nul
  goto :loop

  :end
  del /q "%TEMP_ROLES_FILE%" 2>nul
  endlocal
  exit /b 0
  EOT

  bash_script = <<EOT
  number_roles=$${#${local.required_roles}[@]}
  set_roles=0

  until [[ $set_roles -eq $number_roles ]]; do
    sleep 5
    set_roles=0
    
    roles=$(gcloud projects get-iam-policy ${var.project_id} \
      --flatten="bindings[].members" \
      --format="value(bindings[].role) \
      --filter="bindings.members:serviceAccount:${google_service_account.functions_sa.email}")
    
    for role in "$${{${local.required_roles}[@]}"; do
      if grep -q "^$${role}$" <<< "$roles"; then
        set_roles=$((set_roles+1))
      fi
    done
  done
  EOT
}

resource "null_resource" "validate_functions_iam" {
  depends_on = [time_sleep.wait_for_iam_propagation]
  
  provisioner "local-exec" {
    command = local.is_windows ? local.batch_script : local.bash_script
  }
  
  triggers = {
    service_account = google_service_account.functions_sa.email
    expected_roles = jsonencode(local.functions_sa_permissions)
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

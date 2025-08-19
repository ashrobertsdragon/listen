#!/bin/bash
# Usage: ./create_service_role.sh <project_id> # NOTE: project id NOT project number
set -euo pipefail
PROJECT_ID="${1}"
SERVICE_ACCOUNT="terraform-admin@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud auth application-default login
gcloud iam service-accounts create terraform-admin \
    --description="Terraform admin service account" \
    --display-name="Terraform Admin" \
    --project=${PROJECT_ID}

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/editor"
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="roles/iam.serviceAccountAdmin"

gcloud iam service-accounts keys create .terraform/terraform-key.json \
    --iam-account=${SERVICE_ACCOUNT} \
    --project=${PROJECT_ID}
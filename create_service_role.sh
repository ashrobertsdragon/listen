#!/bin/bash

PROJECT_ID="${1}"

gcloud auth application-default login

gcloud iam service-accounts create terraform-admin \
    --description="Terraform admin service account" \
    --display-name="Terraform Admin" --project=${PROJECT_ID}


gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:terraform-admin@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:terraform-admin@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountAdmin"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
    --iam-account=terraform-admin@${PROJECT_ID}.iam.gserviceaccount.com \
    --project=${PROJECT_ID}

mv terraform-key.json .terraform/terraform-key.json
module "supabase" {
  source = "./modules/supabase"
  supabase_organization_id = var.supabase_organization_id
  supabase_access_token = var.supabase_access_token
  supabase_db_password = var.supabase_db_password
}

module "postgresql" {
  source = "./modules/postgresql"
  supabase_db_host = module.supabase.supabase_db_host
  supabase_db_password = var.supabase_db_password
}

module "http" {
  source = "./modules/http"
  supabase_project_id = module.supabase.supabase_project_id
  supabase_key = module.supabase.supabase_key
}

provider "google" {
  credentials = file("terraform-key.json")
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "functions" {
  source     = "./modules/functions"
  project_id = var.project_id
  region     = var.region
  functions_sa_email = google_service_account.functions_sa.email
  scheduler_sa_email = google_service_account.scheduler_sa.email
  function_names_http = ["download","upload","rss","cleaner"]
  supabase_url = module.supabase.supabase_url
  supabase_key = module.supabase.supabase_key
}

module "endpoints" {
  source = "./modules/endpoints"
  project_id = var.project_id
  region = var.region
}

module "chrome_vm" {
  source = "./modules/chrome_vm"
  project_id = var.project_id
  zone       = var.zone
  ssh_user   = var.ssh_user
  ssh_public_key_file = var.ssh_public_key_file
  ssh_private_key_file = var.ssh_private_key_file
  upload_function_url = module.functions.upload_function_url
  api_key = module.endpoints.api_key
  extension_remote_path = var.extension_remote_path
  period = var.vm_period
}

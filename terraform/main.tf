module "supabase" {
  source = "./modules/supabase"
  supabase_organization_id = var.supabase_organization_id
  supabase_access_token = var.supabase_access_token
  supabase_db_password = var.supabase_db_password
}

provider "google" {
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
  ssh_public_key = var.ssh_public_key
  upload_function_url = module.functions.upload_function_url
  api_key = module.endpoints.api_key
  extension_remote_path = var.extension_remote_path
}

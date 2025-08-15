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
  function_names_http = ["download","upload","tts","rss","cleaner"]
  supabase_url = var.supabase_url
  supabase_key = var.supabase_key
}

module "chrome_vm" {
  source = "./modules/chrome_vm"
  project_id = var.project_id
  region     = var.region
  zone       = var.zone
  ssh_user   = var.ssh_user
  ssh_public_key = var.ssh_public_key
  upload_function_url = module.functions.upload_function_url
  extension_remote_path = var.extension_remote_path
}

module "supabase" {
  source = "./modules/supabase"
  supabase_url = var.supabase_url
  supabase_key = var.supabase_key
}

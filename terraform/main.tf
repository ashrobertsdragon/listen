locals {
   is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
}
module "supabase" {
  source = "./modules/supabase"
  supabase_organization_id = var.supabase_organization_id
  supabase_access_token = var.supabase_access_token
  supabase_db_password = var.supabase_db_password
}

module "dns_check" {
  source = "./modules/dns_check"
  supabase_project_id = module.supabase.supabase_project_id
  supabase_key = module.supabase.supabase_key
  windows = local.is_windows
}

module "postgresql" {
  source = "./modules/postgresql"
  supabase_db_host = module.dns_check.supabase_db_host
  supabase_db_password = var.supabase_db_password
  supabase_rest_url = module.dns_check.supabase_rest_url
  supabase_key        = module.supabase.supabase_key
}

provider "google" {
  credentials = file("terraform-key.json")
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

module "iam" {
  source = "./modules/iam"
  project_id = var.project_id
}

module "functions" {
  source     = "./modules/functions"
  project_id = var.project_id
  region     = var.region
  functions_sa_email = module.iam.functions_service_account_email
  scheduler_sa_email = module.iam.scheduler_service_account_email
  function_names_http = ["download","upload","rss","cleaner"]
  supabase_url = "https://${module.supabase.supabase_project_id}.supabase.co"
  supabase_key = module.supabase.supabase_key
  windows = local.is_windows
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
variable "project_id" {}
variable "region" { default = "us-central1" }
variable "zone"   { default = "us-central1-a" }
variable "ssh_user" {}
variable "ssh_public_key" {}

variable "extension_remote_path" {}
variable "supabase_db_password" {}
variable "supabase_organization_id" {}
variable "supabase_access_token" {}
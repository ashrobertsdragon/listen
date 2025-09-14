variable "project_id" {
  type = string
}
variable "region" {
  default = "us-east1"
  type = string
}
variable "zone"   {
  default = "us-east1-c"
  type = string
}
variable "ssh_user" {
  default = "debian"
  type = string
}
variable "ssh_public_key_file" {
  sensitive = true
  type = string
}
variable "ssh_private_key_file" {
  sensitive = true
  type = string
}
variable "extension_remote_path" {
  default = "/opt/listen-listener"
  type = string
}
variable "supabase_db_password" {
#sensitive = true
  type = string
}
variable "supabase_organization_id" {
  #sensitive = true
  type = string
}
variable "supabase_access_token" {
  #sensitive = true
  type = string
}
variable "vm_period" {
  default = "6H"
  type = string
  description = "Period between VM restarts (6H = 6 hours, 1D = 1 day, 15m = 15 minutes)"
}
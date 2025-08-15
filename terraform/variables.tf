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
variable "ssh_public_key" {
  sensitive = true
  type = string
  default = "C:/Users/ashro/.ssh/id_rsa.pub"
}
variable "ssh_private_key" {
  sensitive = true
  type = string
  default = "C:/Users/ashro/.ssh/id_rsa"
}
variable "extension_remote_path" {
  default = "/opt/listen-listener"
  type = string
}
variable "supabase_db_password" {
  sensitive = true
  type = string
}
variable "supabase_organization_id" {
  sensitive = true
  type = string
}
variable "supabase_access_token" {
  sensitive = true
  type = string
}
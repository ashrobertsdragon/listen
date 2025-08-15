variable "project_id" {}
variable "zone" {}
variable "ssh_user" {}
variable "ssh_public_key" {}
variable "upload_function_url" {}
variable "api_key" {
  sensitive = true
}
variable "extension_remote_path" {
  description = "Full path on VM to listen-listener extension folder (background.js will be patched there)."
}
variable "ssh_private_key" {}
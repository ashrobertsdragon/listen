variable "project_id" {}
variable "region" { default = "us-east1" }
variable "function_names_http" {
  type = list(string)
  default = ["download","upload","rss","cleaner"]
}
variable "runtime" { default = "python310" }
variable "functions_sa_email" {}
variable "scheduler_sa_email" {}
variable "supabase_url" {}
variable "supabase_key" {
  sensitive = true
}
variable "windows" {
  type = bool
  description = "true for Windows, false for Linux/Mac"
}
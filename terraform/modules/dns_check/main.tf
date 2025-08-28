variable "windows" {
  type = bool
  description = "true for Windows, false for Linux/Mac"
}

variable "supabase_project_id" {
  type = string
  description = "value of Supabase project ID"
}

variable "supabase_key" {
  type = string
  description = "Supabase service role key"
  sensitive = true
}

locals {
   host = "${var.supabase_project_id}.supabase.co" 
}

resource "terraform_data" "test_db_connection" {
  triggers_replace = [
    var.supabase_project_id,
    var.supabase_key
  ]

  provisioner "local-exec" {
    interpreter = var.windows ? ["cmd", "/c"] : ["bash"]
    command     = "dns_check.${var.windows ? "bat" : "sh"} ${local.host}"
    working_dir = "${path.module}/scripts"
  }
}

output "host_ready" {
  value = terraform_data.test_db_connection.id
}

output "supabase_db_host" {
  value = "db.${local.host}"
}

output "supabase_rest_url" {
  value ="https://${local.host}/rest/v1/"
}
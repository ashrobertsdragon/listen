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
   rest_url = "https://db.${var.supabase_project_id}.supabase.co/rest/v1/"
}

resource "null_resource" "test_db_connection" {
  triggers = {
    supabase_project_id = var.supabase_project_id
    supabase_key = var.supabase_key
  }

  provisioner "local-exec" {
    interpreter = var.windows ? ["cmd", "/c"] : ["bash"]
    command     = "dns_check.${var.windows ? "bat" : "sh"} ${local.rest_url}"
    working_dir = "${path.module}/scripts"
  }
}

output "supabase_db_host" {
  value = "db.${var.supabase_project_id}.supabase.co"
}

output "supabase_rest_url" {
  value = local.rest_url
}
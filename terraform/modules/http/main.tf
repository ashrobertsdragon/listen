terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

data "http" "execute_sql" {
  for_each          = var.queries

  url               = "https://${var.supabase_project_id}.supabase.co/rest/v1/rpc/exec_sql"
  method            = "POST"
  
  request_headers   = {
    "Authorization" = "Bearer ${tostring(var.supabase_key)}"
    "Content-Type"  = "application/json"
    "apikey"        = tostring(var.supabase_key)
  }

  request_body      = jsonencode({
    query = file("${path.module}/${each.value}")
  })

  depends_on = [module.postgresql.exec_sql]
}
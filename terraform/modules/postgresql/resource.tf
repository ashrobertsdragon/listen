resource "postgresql_function" "create_rpc" {
  name       = "exec_sql"
  schema     = "public"
  returns    = "json"
  language   = "plpgsql"
  body = <<SQL
    declare
      result json;
    begin
      execute query into result;
      return result;
    end;
  SQL

  arg {
    name = "query"
    type = "text"
  }
}

resource "null_resource" "execute_sql" {
  for_each = var.queries

  triggers = {
    query_file_content = file("${path.module}/sql/${each.value}")
    supabase_key      = var.supabase_key
    supabase_rest_url = var.supabase_rest_url
  }

  provisioner "local-exec" {
    command = <<EOT
    curl -X POST "${self.triggers.supabase_rest_url}/rpc/exec_sql" \
     -H "Authorization: Bearer ${self.triggers.supabase_key}" \
     -H "Content-Type: application/json" \
     -H "apikey: ${self.triggers.supabase_key}" \
     -d '${jsonencode({query = self.triggers.query_file_content})}'
EOT
  }

  depends_on = [ postgresql_function.create_rpc ]
}

resource "terraform_data" "wait_for_dns_propagation" {
  triggers_replace = [ var.host_ready ]
}

resource "postgresql_function" "create_rpc" {
  name       = "exec_sql"
  schema     = "public"
  returns    = "json"
  language   = "plpgsql"
  security_definer = true
  body = <<SQL
    DECLARE
      result json;
    BEGIN
      IF current_setting('request.jwt.claims.role', true) <> 'service_role' THEN
        RAISE EXCEPTION 'Unauthorized';
      END IF;
      SET LOCAL search_path TO public;
      EXECUTE query;
      result := json_build_object('status', 'success');
      RETURN result;
    EXCEPTION
      WHEN others THEN
        RETURN json_build_object('error', SQLERRM);
    END;
  SQL

  arg {
    name = "query"
    type = "text"
  }

  depends_on = [ terraform_data.wait_for_dns_propagation ]
}

resource "terraform_data" "execute_sql" {
  for_each = var.queries

  input = {
    query_file_content = file("${path.module}/sql/${each.value}")
  }

  triggers_replace = [
    file("${path.module}/sql/${each.value}"),
    var.supabase_key,
    var.supabase_rest_url
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Executing SQL from ${each.value}..."
      curl -X POST "${var.supabase_rest_url}/rpc/exec_sql" \
        -H "Authorization: Bearer ${var.supabase_key}" \
        -H "Content-Type: application/json" \
        -H "apikey: ${var.supabase_key}" \
        -d '${jsonencode({query = self.input.query_file_content})}' \
        --fail-with-body
      if [ $? -ne 0 ]; then
        echo "Failed to execute SQL from ${each.value}"
        exit 1
      fi
      echo "Successfully executed SQL from ${each.value}"
      EOT
  }

  depends_on = [ postgresql_function.create_rpc ]
}

resource "postgresql_function" "exec_sql" {
  name       = "exec_sql"
  schema     = "public"
  returns    = "json"
  language   = "plpgsql"
  body = <<-SQL
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

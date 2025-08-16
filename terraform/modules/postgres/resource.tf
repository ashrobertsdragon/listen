resource "postgresql_query" "migrations" {
  query = file("${path.module}/migrations.sql")
}

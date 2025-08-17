resource "supabase_project" "personal_podcast" {
  organization_id = var.supabase_organization_id
  name = "personal-podcast"
  region = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password]
  }
}

data "supabase_apikeys" "personal_podcast" {
  project_ref = supabase_project.personal_podcast.id
}

resource "terraform_data" "database_tables" {
  depends_on = [ supabase_project.personal_podcast ]

  for_each = toset(var.queries)

  provisioner "local-exec" {
    command = "psql  postgres://postgres:${var.supabase_db_password}@${supabase_project.personal_podcast.id}.supabase.co:5432/postgres?sslmode=require -f ${path.module}/${each.value}"
  }

}
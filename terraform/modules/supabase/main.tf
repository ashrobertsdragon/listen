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


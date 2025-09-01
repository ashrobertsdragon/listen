resource "supabase_project" "personal_podcast" {
  organization_id = var.supabase_organization_id
  name = "personal-podcast"
  region = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    prevent_destroy = false
    ignore_changes = [ database_password ]
    postcondition {
      condition     = self.id != ""
      error_message = "Project creation failed - no project ID returned"
    }
  }
}

resource "time_sleep" "wait_30s" {
  depends_on = [supabase_project.personal_podcast]
  create_duration = "30s"
}

resource "terraform_data" "block_on_project_creation" {
  depends_on = [ supabase_project.personal_podcast ]

  triggers_replace = [ supabase_project.personal_podcast.id ]
  input = {
    project_id = supabase_project.personal_podcast.id
  }
}
data "supabase_apikeys" "personal_podcast" {
  project_ref = supabase_project.personal_podcast.id
  depends_on  = [ time_sleep.wait_30s ]
}
resource "supabase_project" "personal_podcast" {
  organization_id = var.supabase_organization_id
  name = "personal-podcast"
  region = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password]
  }
}

resource "null_resource" "wait_for_project" {
  depends_on = [supabase_project.personal_podcast]
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

data "supabase_apikeys" "personal_podcast" {
  project_ref = supabase_project.personal_podcast.id
  depends_on  = [time_sleep.wait_for_project]
}

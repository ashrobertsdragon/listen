output "supabase_key" {
  value     = data.supabase_apikeys.personal_podcast.service_role_key
  sensitive = true
}

output "supabase_url" {
  value = "https://${resource.supabase_project.personal_podcast.id}.supabase.co"
}

output "supabase_db_host" {
  value = "db.${resource.supabase_project.personal_podcast.id}.supabase.co"
}

output "supabase_project_id" {
  value = supabase_project.personal_podcast.id
}

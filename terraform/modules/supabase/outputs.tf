output "supabase_key" {
  value     = data.supabase_apikeys.personal_podcast.service_role_key
  sensitive = true
}

output "supabase_project_id" {
  value = supabase_project.personal_podcast.id
}

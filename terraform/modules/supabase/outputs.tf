output "listen_tab_podcast_bucket" {
  value = "listen_tab_podcast"
}

output "supabase_key" {
  value     = data.supabase_apikeys.personal_podcast.service_role_key
  sensitive = true
}

output "supabase_url" {
  value = "https://${resource.supabase_project.personal_podcast.id}.supabase.co"
}
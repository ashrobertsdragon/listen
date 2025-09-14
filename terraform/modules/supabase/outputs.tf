output "supabase_key" {
  value = data.supabase_apikeys.personal_podcast.service_role_key
}

output "supabase_project_id" {
  value = supabase_project.personal_podcast.id
}

output "supabase_rest_url" {
  value = "https://${supabase_project.personal_podcast.id}.supabase.co/rest/v1/"
}

output "bucket_name" {
  value = local.bucket_name
}

output "supabase_key" {
  value     = data.supabase_apikeys.personal_podcast.service_role_key
  sensitive = true
}

output "supabase_project_id" {
  value = terraform_data.block_on_project_creation.output.id # "project_id" passthru
}

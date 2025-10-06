output "upload_function_url" {
  value = module.functions.upload_function_url
}

output "supabase_bucket" {
  value = module.supabase.bucket_name
}


output "desktop_extension_config" {
  description = "Configuration values for desktop extension (copy these into extension options)"
  value = {
    supabase_url = module.supabase.supabase_rest_url
    tab_group_name = "listen"
  }
}

output "supabase_service_key" {
  description = "Supabase service role key (sensitive - for desktop extension setup)"
  value = module.supabase.supabase_key
  sensitive = true
}

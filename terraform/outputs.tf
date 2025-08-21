output "upload_function_url" {
  value = module.functions.upload_function_url
}

output "supabase_bucket" {
  value = module.postgresql.supabase_bucket_name
}


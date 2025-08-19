output "supabase_bucket_name" {
  value = regex("(?i)values\\s*\\(\\s*'([^']+)'", replace(file("${path.module}/bucket.sql"), "\r\n", "\n"))[0]
}

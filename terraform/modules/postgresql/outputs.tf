output "supabase_bucket_name" {
  value = regex("(?i)values\\s*\\(\\s*'([^']+)'", replace(file("${path.module}/sql/bucket.sql"), "\r\n", "\n"))[0]
}

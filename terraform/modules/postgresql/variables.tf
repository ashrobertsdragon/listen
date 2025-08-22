variable supabase_db_host {}
variable supabase_db_password {}
variable "supabase_rest_url" {
}
variable "supabase_key" {
  sensitive = true
}
variable "windows" {
  type = bool
  description = "true for Windows, false for Linux/Mac"
}
variable "queries" {
    type = set(string)
    default = [
        "bucket.sql",
        "listen_table.sql",
        "character_count.sql",
        "index.sql"
    ]
}
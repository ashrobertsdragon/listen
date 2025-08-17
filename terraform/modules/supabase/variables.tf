variable "supabase_organization_id" {}
variable "supabase_access_token" {}
variable "supabase_db_password" {}
variable "supabase_region" { default = "us-east-2" }
variable "queries" {
    type = list(string)
    default = [
        "bucket.sql",
        "listen_table.sql",
        "character_count.sql",
        "index.sql"
    ]
}
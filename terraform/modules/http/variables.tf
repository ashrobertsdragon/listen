variable "queries" {
    type = set(string)
    default = [
        "bucket.sql",
        "listen_table.sql",
        "character_count.sql",
        "index.sql"
    ]
}

variable "supabase_project_id" {}
variable "supabase_key" {}
resource "supabase_project" "personal_podcast" {
  organization_id = var.supabase_organization_id
  name = "personal-podcast"
  region = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password]
  }
}

data "supabase_apikeys" "personal_podcast" {
  project_ref = supabase_project.personal_podcast.id
}

resource "supabase_storage_bucket" "podcast_bucket" {
  name = "listen_tab_podcast"
}

resource "supabase_db_sql" "listen_table" {
  sql = <<EOT
CREATE TABLE IF NOT EXISTS listen (
    guid uuid PRIMARY KEY,
    title text,
    created_at timestamptz DEFAULT now(),
    last_download timestamptz,
    audio_url text
);
EOT
}

resource "supabase_db_sql" "character_count_table" {
  sql = <<EOT
CREATE TABLE IF NOT EXISTS character_count (
    count int,
    month int,
    year int
);
CREATE INDEX IF NOT EXISTS month_year_idx ON character_count (month, year);
EOT
}

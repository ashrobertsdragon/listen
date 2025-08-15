provider "supabase" {
  supabase_key = var.supabase_key
  supabase_url     = var.supabase_url
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

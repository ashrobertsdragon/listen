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

resource "terraform_data" "storage_bucket" {
  depends_on = [supabase_project.personal_podcast]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST "https://${self.input.project_id}.supabase.co/storage/v1/bucket" \
        -H "Authorization: Bearer ${self.input.service_role_key}" \
        -H "Content-Type: application/json" \
        -d '{"id":"listen_tab_podcast","name":"listen_tab_podcast","public":true,"file_size_limit":52428800,"allowed_mime_types":["audio/mp3"]}'
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      curl -X DELETE "https://${self.input.project_id}.supabase.co/storage/v1/bucket/listen_tab_podcast" \
        -H "Authorization: Bearer ${self.input.service_role_key}" || true
    EOT
  }

  input = {
    project_id       = supabase_project.personal_podcast.id
    service_role_key = data.supabase_apikeys.personal_podcast.service_role_key
  }
}

resource "terraform_data" "database_tables" {
  depends_on = [supabase_project.personal_podcast]

  provisioner "local-exec" {
    command = <<EOT
      psql "postgresql://postgres:${var.supabase_db_password}@db.${supabase_project.personal_podcast.id}.supabase.co:5432/postgres?sslmode=require" \
        -c "
CREATE TABLE IF NOT EXISTS listen (
    guid uuid PRIMARY KEY,
    title text,
    created_at timestamptz DEFAULT now(),
    last_download timestamptz,
    audio_url text
);

CREATE TABLE IF NOT EXISTS character_count (
    count int,
    month int,
    year int
);

CREATE INDEX IF NOT EXISTS month_year_idx ON character_count (month, year);
        "
    EOT
  }

  triggers_replace = [
    supabase_project.personal_podcast.id,
    sha256(<<EOT
CREATE TABLE IF NOT EXISTS listen (
    guid uuid PRIMARY KEY,
    title text,
    created_at timestamptz DEFAULT now(),
    last_download timestamptz,
    audio_url text
);

CREATE TABLE IF NOT EXISTS character_count (
    count int,
    month int,
    year int
);

CREATE INDEX IF NOT EXISTS month_year_idx ON character_count (month, year);
EOT
    )
  ]
}
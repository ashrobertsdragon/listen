resource "supabase_project" "personal_podcast" {
  organization_id   = var.supabase_organization_id
  name              = "personal-podcast"
  region            = var.supabase_region
  database_password = var.supabase_db_password

  lifecycle {
    ignore_changes = [database_password]
  }
}

resource "time_sleep" "wait_30s" {
  depends_on      = [supabase_project.personal_podcast]
  create_duration = "30s"
}

data "supabase_apikeys" "personal_podcast" {
  project_ref = supabase_project.personal_podcast.id

  depends_on = [
    supabase_project.personal_podcast,
    time_sleep.wait_30s
  ]
}

resource "terraform_data" "block_on_project_creation" {
  depends_on = [
    supabase_project.personal_podcast,
    time_sleep.wait_30s
  ]

  triggers_replace = [supabase_project.personal_podcast.id]
  input = {
    project_id = supabase_project.personal_podcast.id
  }
}

locals {
  bucket_name = "listen_podcast_${md5(supabase_project.personal_podcast.name)}"

  bucket_sql = <<-EOF
    INSERT INTO
    storage.buckets (
        id,
        name,
        public,
        allowed_mime_types
    )
        VALUES
        (
            '${local.bucket_name}',
            '${local.bucket_name}',
            true,
            ARRAY['audio/mp3']
        )
        ON CONFLICT (
            id
        )
        DO NOTHING;
    EOF

  static_sql = {
    for q in fileset("${path.module}/sql", "*.sql") : q => file("${path.module}/sql/${q}")
  }
  all_queries = merge(local.static_sql, { "bucket_sql" = local.bucket_sql })
}

resource "terraform_data" "migrate_db" {
  for_each = local.all_queries

  input = {
    query = jsonencode({ query = each.value })
  }

  depends_on       = [terraform_data.block_on_project_creation]
  triggers_replace = [supabase_project.personal_podcast.id]

  provisioner "local-exec" {
    working_dir = "${path.module}/scripts"
    command     = "migrate.${var.windows ? "bat" : "sh"} ${supabase_project.personal_podcast.id} ${var.supabase_access_token} ${self.input.query}"
  }
}

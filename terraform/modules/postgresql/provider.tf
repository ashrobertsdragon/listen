terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "1.25.0"
    }
        time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}

provider "postgresql" {
  host                 = var.supabase_db_host
  port                 = 5432
  database             = "postgres"
  username             = "postgres"
  password             = var.supabase_db_password
  sslmode              = "require"
  connect_timeout      = 15
}


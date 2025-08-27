resource "google_endpoints_service" "api_gateway" {
  service_name = "${var.project_id}.appspot.com"
  openapi_config = templatefile("${path.module}/openapi-schema.yml", {
    project_id = var.project_id
    region     = var.region
  })
}

resource "random_id" "key_suffix" {
  byte_length = 4
}

resource "google_apikeys_key" "tts_api_key" {
  name         = "tts-api-key-${random_id.key_suffix.hex}"
  display_name = "TTS API Key"
  
  restrictions {
    api_targets {
      service = google_endpoints_service.api_gateway.service_name
    }
  }
}
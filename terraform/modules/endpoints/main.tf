resource "google_endpoints_service" "api_gateway" {
  service_name = "${var.project_id}.appspot.com"
  openapi_config = templatefile("${path.module}/openapi-schema.yml", {
    project_id = var.project_id
    region     = var.region
  })
}

resource "google_apikeys_key" "tts_api_key" {
  name         = "tts-api-key"
  display_name = "TTS API Key"
  
  restrictions {
    api_targets {
      service = google_endpoints_service.api_gateway.service_name
    }
  }
}
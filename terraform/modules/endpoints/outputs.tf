output "api_key" {
  value     = google_apikeys_key.tts_api_key.key_string
  sensitive = true
}

output "api_gateway_url" {
  value = "https://${google_endpoints_service.api_gateway.service_name}"
}